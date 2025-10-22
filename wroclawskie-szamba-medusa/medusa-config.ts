import { loadEnv, defineConfig } from '@medusajs/framework/utils';

loadEnv(process.env.NODE_ENV || 'development', process.cwd());

module.exports = defineConfig({
  projectConfig: {
    databaseUrl: process.env.DATABASE_URL,
    redisUrl: process.env.REDIS_URL,
    workerMode:
      (process.env.WORKER_MODE as 'shared' | 'worker' | 'server') || 'shared',
    http: {
      storeCors: process.env.STORE_CORS!,
      adminCors: process.env.ADMIN_CORS!,
      authCors: process.env.AUTH_CORS!,
      jwtSecret: process.env.JWT_SECRET || 'supersecret',
      cookieSecret: process.env.COOKIE_SECRET || 'supersecret',
    },
    databaseDriverOptions:
      process.env.NODE_ENV === 'production'
        ? {
            connection: {
              ssl: { rejectUnauthorized: false },
            },
          }
        : { ssl: false, sslmode: 'disable' },

    cookieOptions: {
      sameSite: process.env.NODE_ENV === 'production' ? 'none' : 'lax',
      secure: process.env.NODE_ENV === 'production' ? true : false,
    },
  },
  modules: [
    {
      resolve: '@medusajs/medusa/file',
      options: {
        providers: [
          {
            resolve: './src/modules/azure-file',
            id: 'azure-blob',
            options: {
              account_name: process.env.AZURE_STORAGE_ACCOUNT_NAME,
              account_key: process.env.AZURE_STORAGE_ACCOUNT_KEY,
              container_name: process.env.AZURE_STORAGE_CONTAINER || 'uploads',
              prefix: 'medusa',
              cache_control: 'public, max-age=31536000',
              download_url_duration: 3600,
            },
          },
        ],
      },
    },
  ],
});
