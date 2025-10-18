#!/bin/sh
set -e

echo "🔧 Injecting runtime environment variables into Next.js build..."

# Replace placeholder API key with actual runtime value in all JS files
if [ -n "$NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY" ]; then
  echo "📝 Replacing API key placeholder with actual key..."
  find /app/.next/static -type f -name "*.js" -exec sed -i "s/pk_build_placeholder/$NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY/g" {} +
  echo "✅ API key injected successfully"
else
  echo "⚠️  Warning: NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY not set!"
fi

# Replace BASE_URL if needed
if [ -n "$NEXT_PUBLIC_BASE_URL" ]; then
  echo "📝 Replacing BASE_URL placeholder..."
  find /app/.next/static -type f -name "*.js" -exec sed -i "s|http://localhost:8000|$NEXT_PUBLIC_BASE_URL|g" {} +
  echo "✅ BASE_URL injected successfully"
fi

echo "🚀 Starting Next.js server..."
exec node server.js
