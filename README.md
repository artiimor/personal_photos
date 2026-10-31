# Personal Photos

Aplicación Rails para guardar fotos personales. Cada usuario se registra (Devise), sube sus fotos desde el navegador y ve su galería con miniaturas.

Las fotos **no se guardan en este proyecto**: se almacenan en [file-uploader](../file-uploader), un servidor de ficheros escrito en Rust (Axum). Rails solo guarda en Postgres los metadatos (la foto, su usuario y el blob de Active Storage).

## Cómo se comunica con file-uploader

La integración es un servicio propio de Active Storage, `ActiveStorage::Service::FileUploaderService` (`lib/active_storage/service/file_uploader_service.rb`), configurado como `file_uploader` en `config/storage.yml`.

- **Claves por usuario**: cada blob tiene una key `<user_id>/<uuid>.<ext>` (la genera `CustomDirectUploadsController`). De ahí salen el usuario y el nombre de fichero en file-uploader.
- **Endpoints**: `PUT`, `GET` y `DELETE` sobre `/files/:user_id/:file_name`.
- **Autenticación con JWT**: cada petición lleva un `?token=` firmado con HS256 y `FILE_UPLOADER_JWT_SECRET`, con los claims `sub` (usuario), `scope` (`upload`, `download` o `delete`), `file_name` y una caducidad de 5 minutos. file-uploader lo verifica con su `JWT_SECRET`, así que **los dos secretos tienen que coincidir**.
- **Subida directa**: el navegador sube el fichero directamente a file-uploader con la URL firmada que genera Rails, sin pasar los bytes por la app.
- **Miniaturas**: la variante `:thumb` (300x300, WebP) la genera Rails con libvips y la vuelve a guardar en file-uploader. `GET /photos/:id/thumb` redirige a su URL firmada.
- **Errores**: las respuestas 404, 422 y 401/403 de file-uploader se traducen a errores de Active Storage (`FileNotFoundError`, `IntegrityError`, `Error`).

## Requisitos

- Docker y Docker Compose
- file-uploader arrancado en el host, escuchando en el puerto `3050`

## Arrancar con Docker

1. Crea el `.env` a partir del ejemplo y ajusta los valores:

   ```sh
   cp .env.example .env
   ```

   | Variable | Para qué sirve |
   | --- | --- |
   | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` | Credenciales de la base de datos |
   | `DATABASE_URL`, `REDIS_URL` | Conexiones a los contenedores `db` y `redis` |
   | `FILE_UPLOADER_URL` | URL de file-uploader vista desde el contenedor (por defecto `http://host.docker.internal:3050`) |
   | `FILE_UPLOADER_PUBLIC_URL` | Opcional. URL de file-uploader vista desde el navegador (p. ej. `http://localhost:3050`). Si no se define, se usa `FILE_UPLOADER_URL` |
   | `FILE_UPLOADER_JWT_SECRET` | Secreto para firmar los tokens. Igual que el `JWT_SECRET` de file-uploader |

2. Arranca file-uploader con el mismo secreto. Para que el navegador pueda subir ficheros, su `ALLOWED_ORIGINS` debe incluir `http://localhost:3000`.

3. Levanta la aplicación:

   ```sh
   docker compose up --build
   ```

   Se arrancan estos servicios:

   | Servicio | Qué hace |
   | --- | --- |
   | `web` | Rails en http://localhost:3000 (ejecuta `db:prepare` al arrancar) |
   | `css` | `tailwindcss:watch` para recompilar los estilos |
   | `sidekiq` | Jobs en segundo plano |
   | `db` | Postgres 17 (puerto `5432`) |
   | `redis` | Redis 7 |

   El código está montado como volumen, así que los cambios se ven sin reconstruir la imagen. Solo hace falta `--build` si cambia el `Gemfile`.

4. Abre http://localhost:3000, regístrate y sube una foto.

## Tests

Los tests usan RSpec y llevan stubs de las llamadas a file-uploader, así que no hace falta tenerlo arrancado:

```sh
docker compose --env-file .env.test run --rm -e RAILS_ENV=test web \
  bash -c "bin/rails db:prepare && bundle exec rspec"
```
