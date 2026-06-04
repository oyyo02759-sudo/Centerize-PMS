import { ConfigService } from '@nestjs/config';

/** Build Prisma/PostgreSQL URL from DB_* vars (docker-compose defaults). */
export function buildDatabaseUrl(config: ConfigService): string {
  const host = config.get<string>('DB_HOST', 'localhost');
  const port = config.get<number>('DB_PORT', 5432);
  const user = config.get<string>('DB_USER', 'postgres');
  const password = config.get<string>('DB_PASSWORD', 'postgres');
  const database = config.get<string>('DB_NAME', 'centerize_pms');
  const encodedPassword = encodeURIComponent(password);
  return `postgresql://${user}:${encodedPassword}@${host}:${port}/${database}?schema=public`;
}

export function resolveDatabaseUrl(config: ConfigService): string {
  return config.get<string>('DATABASE_URL') ?? buildDatabaseUrl(config);
}
