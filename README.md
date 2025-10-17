# WroclawskieSzamba24.pl
# 17/10/25
<img width="100%" alt="Screenshot_20251012_172221" src="https://github.com/user-attachments/assets/79b3a52e-2c79-44a4-a85e-2b96cbd2bf07" />


## Building (Docker)
> [!NOTE]
> Update the ENVs in `.env` and `docker-compose.yml`

### Seeding the database [optional]

Skip this step if you don't want the database to be populated with default values or it is too much pain 😵

1. Build & start `postgres`, `redis` & `db_seeder`

```sh
docker compose -f docker-compose.yml -f docker-compose-seed.yml up --build postgres redis db_seeder
```

2. Stop the containers
3. You can remove the `db_seeder` container

```sh
docker compose -f docker-compose.yml -f docker-compose-seed.yml down db_seeder
```

### Building Backend (Medusa)

```sh
docker compose up --build postgres redis medusa
```

### Get the API key (storefront <-> medusa)

<img width="100%" alt="Screenshot_20251012_120447" src="https://github.com/user-attachments/assets/4a8273ad-a84f-461d-805d-2890591aacae" />


You need an API key generated in the medusa admin panel for the storefront to be able to connect

Default admin credentials -> [db_seed.sh](./db_seed.sh)

Set that key in .env (`NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY`)

- https://docs.medusajs.com/resources/storefront-development/publishable-api-keys

### Build storefront

```sh
docker compose up --build storefront
```

---

## Starting containers

```sh
docker compose up
```

## Removing containers

```sh
docker compose down
```

### Removing volumes

#### One-liner

```sh
docker volume ls -q | grep '^wroclawskie-szamba' | xargs -r docker volume rm
```

#### List apps' volumes

```sh
docker volume ls -q | grep '^wroclawskie-szamba'
```

#### Remove volumes

```sh
docker volume rm <VOLUME>
```

---

## Resources

### Images

- https://pixabay.com/photos/sewage-truck-faeces-cesspool-5940760/
- https://pixabay.com/vectors/poo-emoji-poop-brown-smiley-6783251/

### Music

- generated with suno's v5 beta model (https://suno.com/)
