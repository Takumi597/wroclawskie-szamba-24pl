#!/bin/sh

echo "Running database migrations..."
npx medusa db:migrate

echo "Seeding database..."
npm run seed

echo "Creating Admin User"
npx medusa user -e admin@medusajs.com -p supersecret

# echo "Starting Medusa development server..."
# npm run dev

echo "Exiting ..."
exit 0
