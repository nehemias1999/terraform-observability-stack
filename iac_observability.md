# terraform-observability-stack

**Descripción:** IaC deployment using Terraform and Docker Compose. Provisions an immutable environment with Traefik, Prometheus, Grafana, and PostgreSQL optimized for standard Linux LTS hosts.

## 1. Resumen del Proyecto (De qué trata)
Este proyecto demuestra el dominio de **Infraestructura como Código (IaC)** y **Observabilidad**. Utiliza Terraform para aprovisionar una máquina virtual (EC2 en AWS o Compute Engine en GCP) y configurar sus reglas de red. Una vez levantada la infraestructura, se despliega un stack de Docker Compose que incluye un reverse proxy, monitorización en tiempo real, una base de datos relacional y una aplicación "dummy" de consumo.

## 2. Propuesta de Arquitectura
*   **Diseño:** Arquitectura de nodo único (*Single-node*) gestionada como código, orquestada internamente por Docker Compose.
*   **Trade-offs:** 
    *   *Ventaja:* Extremadamente costo-eficiente, rápido de desplegar y fácil de razonar (ideal para entornos de desarrollo/QA o proyectos iniciales).
    *   *Desventaja:* Carece de Alta Disponibilidad (HA). Si la VM cae, hay tiempo de inactividad. (Aceptable para el alcance de este portafolio).

## 3. Stack Tecnológico
*   **Infraestructura:** Terraform, AWS/GCP.
*   **Orquestación:** Docker Engine, Docker Compose.
*   **Redes y Proxy:** Traefik (Reverse Proxy, SSL termination simulada).
*   **Observabilidad:** Prometheus (Métricas), Grafana (Dashboards).
*   **Persistencia:** PostgreSQL.

## 4. Estrategia de DevOps y CI/CD
El flujo de trabajo se centra en el ciclo de vida de la infraestructura:
1.  **Validate & Format:** `terraform fmt` y `terraform validate` en cada commit.
2.  **Plan:** Ejecución de `terraform plan` en los *Pull Requests* para revisión de cambios.
3.  **Apply:** Ejecución de `terraform apply` al hacer merge a la rama `main`.
4.  **Provisioning:** Uso de `user_data` (cloud-init) o un aprovisionador como Ansible/Bash para instalar Docker y lanzar el `docker-compose.yml`.

## 5. Estructura del Repositorio
```text
├── terraform/
│   ├── main.tf                 # Proveedor y recursos principales
│   ├── variables.tf
│   ├── outputs.tf
│   └── user_data.sh            # Script de inicialización de la VM
├── compose/
│   ├── docker-compose.yml      # Definición de Traefik, App, DB, Prometheus, Grafana
│   ├── prometheus/
│   │   └── prometheus.yml      # Configuración de scrapeo
│   └── grafana/
│       └── provisioning/       # Dashboards como código
└── .github/workflows/
    └── terraform-ci.yml        # Pipeline de GitHub Actions
```

## 6. Buenas Prácticas y Operaciones
*   **Estado Remoto:** Terraform state se guarda en un bucket S3/GCS con bloqueo (DynamoDB/Locking) para evitar colisiones.
*   **Persistencia:** Se utilizan `Docker Volumes` nombrados para PostgreSQL y Grafana, asegurando que los datos sobrevivan a la recreación de contenedores.
*   **Observabilidad:** Traefik expone métricas automáticamente a Prometheus, que luego se visualizan en un dashboard pre-configurado en Grafana.