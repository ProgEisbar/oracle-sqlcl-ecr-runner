# Oracle SQLcl Runner Image

Imagen de contenedor con Java y Oracle SQLcl preparada para ejecutar automatizaciones de base de datos desde runners CI/CD. El proyecto incluye una construcción multi-stage y un pipeline de GitLab que publica imágenes versionadas en un repositorio privado de Amazon ECR.

La imagen contiene únicamente las herramientas de ejecución. Las credenciales de Oracle, la configuración de red y los permisos AWS se proporcionan en tiempo de ejecución y no forman parte del contenedor.

## Contenido

- `Dockerfile`: instala SQLcl sobre Eclipse Temurin JRE y ejecuta el contenedor con un usuario sin privilegios.
- `.dockerignore`: excluye metadatos y artefactos locales del contexto de construcción.
- `.gitlab-ci.yml`: construye, etiqueta y publica la imagen en ECR.

## Construcción local

```bash
docker build \
  --build-arg SQLCL_VERSION=24.3.2.330.1718 \
  --tag oracle-sqlcl-runner:local \
  .
```

Comprobar la instalación:

```bash
docker run --rm oracle-sqlcl-runner:local sql -v
```

## Preparación de ECR

Definir los valores del ambiente sin incorporarlos al repositorio:

```bash
export AWS_ACCOUNT_ID="<AWS_ACCOUNT_ID>"
export AWS_REGION="<AWS_REGION>"
export ECR_REPOSITORY="<ECR_REPOSITORY>"
```

Crear el repositorio con tags inmutables:

```bash
aws ecr create-repository \
  --repository-name "$ECR_REPOSITORY" \
  --image-tag-mutability IMMUTABLE \
  --encryption-configuration encryptionType=AES256 \
  --region "$AWS_REGION"
```

La configuración de escaneo se administra a nivel del registry. Para escaneo continuo con Amazon Inspector:

```bash
aws ecr put-registry-scanning-configuration \
  --scan-type ENHANCED \
  --rules '[{"scanFrequency":"CONTINUOUS_SCAN","repositoryFilters":[{"filter":"*","filterType":"WILDCARD"}]}]' \
  --region "$AWS_REGION"
```

El escaneo mejorado puede generar cargos de Amazon Inspector.

## Variables de GitLab CI/CD

El pipeline espera las siguientes variables:

| Variable | Descripción |
|---|---|
| `AWS_ACCOUNT_ID` | Cuenta propietaria del registry ECR. |
| `AWS_REGION` | Región donde existe el repositorio. |
| `ECR_REPOSITORY` | Nombre del repositorio de imágenes. |
| `RUNNER_TAG` | Tag del runner habilitado para construir la imagen. |
| `IMAGE_TAG` | Tag de la imagen; usa `CI_COMMIT_SHORT_SHA` de forma predeterminada. |

Las credenciales AWS deben provenir del rol de la instancia, identidad del runner u OIDC. Si se utilizan variables, deben estar protegidas y enmascaradas. El pipeline requiere permisos de push sobre el repositorio ECR y `ecr:GetAuthorizationToken`.

La configuración incluida usa Docker-in-Docker. El runner debe estar habilitado para ese modo de ejecución; si la plataforma no permite runners privilegiados, se debe sustituir el job por un builder compatible con la política de la organización.

## Uso desde DBUP

Una vez publicada, la imagen puede configurarse en DBUP mediante una variable CI/CD:

```text
DBUP_SQLCL_IMAGE=<AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/<ECR_REPOSITORY>:<IMAGE_TAG>
```

El rol utilizado por el runner de DBUP necesita permisos de pull sobre el repositorio. La conectividad con Oracle depende de la red donde se ejecuta el runner: rutas, DNS, security groups y controles de acceso deben configurarse fuera de la imagen.

Para despliegues reproducibles se recomienda consumir un tag inmutable o el digest de la imagen, no `latest`.

## Consideraciones de seguridad

- No incorporar contraseñas, wallets, archivos `.env` ni cadenas de conexión a la imagen.
- Separar los permisos de push del pipeline de construcción y los permisos de pull del runner de ejecución.
- Renovar la autenticación de Docker en cada pipeline; el token de ECR es temporal.
- Mantener Java, Alpine y SQLcl actualizados y volver a construir la imagen ante vulnerabilidades.
- Aplicar una política de ciclo de vida para retirar imágenes antiguas o sin tag.
