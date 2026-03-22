resource "google_sql_database_instance" "prod_mysql" {
  name             = "${var.environment}-prod-mysql"
  database_version = "MYSQL_8_0"
  region           = var.region
  project          = var.project_id

  settings {
    tier              = "db-custom-2-7680"
    availability_type = "REGIONAL"
    disk_size         = 20
    disk_type         = "PD_SSD"

    backup_configuration {
      enabled            = true
      start_time         = "03:00"
      binary_log_enabled = true
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_id
    }
  }

  deletion_protection = var.deletion_protection
}

resource "google_sql_database" "javaapp" {
  name     = var.db_name
  instance = google_sql_database_instance.prod_mysql.name
  project  = var.project_id
}

resource "google_sql_user" "root" {
  name     = "root"
  instance = google_sql_database_instance.prod_mysql.name
  host     = "%"
  password = var.db_root_password
  project  = var.project_id
}
