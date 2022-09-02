import fastify, { FastifyReply, FastifyRequest } from "fastify";
import { config } from "dotenv";
import pino from "pino";
import { randomUUID } from "crypto";

declare global {
  namespace NodeJS {
    interface ProcessEnv {
      AUTH_TOKEN: string;
      NODE_ENV: string;
    }
  }
}

config();

// AUTH_TOKEN processing
if (process.env.AUTH_TOKEN == null) {
  throw "expected 'AUTH_TOKEN' environment variable to be here upon starting the server";
}

if (!process.env.AUTH_TOKEN.startsWith("Bearer ")) {
  process.env.AUTH_TOKEN = "Bearer " + process.env.AUTH_TOKEN;
}

interface ServerInfo {
  lastActivityTime: number;
  token: string;
}

const activeServers = new Map<string, ServerInfo>();

const logger = pino({
  name: "API Server",
  level: "debug",
  transport: {
    target: "pino-pretty",
    options: {
      colorize: true,
    },
  },
});
const server = fastify({ logger });

function getServerId({ headers }: FastifyRequest) {
  const auth = headers.authorization;
  const server_id = headers["server"];
  if (auth != process.env.AUTH_TOKEN || server_id === undefined) {
    // do not send any response, we're going to disguise as a
    // non-existing website so that hackers won't have time to
    // bypass our server anyway.
    server.log.warn("Someone went through our server!");
    return;
  }
  return server_id as string;
}

function getToken({ headers }: FastifyRequest, res: FastifyReply) {
  const token = headers["token"];
  if (typeof token == "string") return token as string;

  res.code(403);
  res.type("application/json");
  res.send(JSON.stringify({ success: false, message: "Invalid information!" }));
}

function checkAuthorization(
  serverId: string,
  token: string,
  res: FastifyReply,
) {
  const info = activeServers.get(serverId);
  if (info != undefined) {
    if (info.token == token || process.env.NODE_ENV === "debug") {
      return true;
    }
    res.code(403);
    res.type("application/json");
    res.send(
      JSON.stringify({ success: false, message: "Invalid information!" }),
    );
  }
  res.code(401);
  res.type("application/json");
  res.send(JSON.stringify({ success: false, message: "Not registered" }));
  return false;
}

server.post("/logout", (req, res) => {
  const serverId = getServerId(req);
  if (!serverId) return;

  const token = getToken(req, res);
  if (token === undefined) return;
  if (!checkAuthorization(serverId, token, res)) return;

  activeServers.delete(serverId);
  server.log.info(`Server (${serverId}) logged out`);
  res.code(200);
  res.type("application/json");
  res.send(JSON.stringify({ success: true, message: "Logged out" }));
});

server.post("/register", (req, res) => {
  const serverId = getServerId(req);
  if (!serverId) return;

  const token = randomUUID();
  activeServers.set(serverId, {
    lastActivityTime: Date.now(),
    token,
  });

  // register the server and then send a JSON file
  // with the token on it
  server.log.info(`Registered server (${serverId})`);
  res.code(200);
  res.type("application/json");
  res.send(JSON.stringify({ success: true, token }));
});

server.listen({ port: 8080 }).catch(reason => {
  server.log.error(`Failed to initialize server: ${reason}`);
  process.exit(1);
});

const fiveMinutes = 5 * 60 * 1000;
setInterval(() => {
  const currentTime = Date.now();
  for (const [id, info] of activeServers.entries()) {
    const elapsed = currentTime - info.lastActivityTime;
    if (elapsed >= fiveMinutes) {
      server.log.info(
        `Deregistering server (${id}, no activity after about 5 minutes)`,
      );
      activeServers.delete(id);
    }
  }
}, fiveMinutes);
