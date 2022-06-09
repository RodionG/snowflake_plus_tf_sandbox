terraform {
  required_providers {
    snowflake = {
      source  = "chanzuckerberg/snowflake"
      version = "0.22.0"
    }
  }
}

variable "SANDBOX_SNOWFLAKE_USER" {
    type = string
}

variable "SANDBOX_SNOWFLAKE_PRIVATE_KEY_PATH" {
    type = string
}

variable "SANDBOX_SNOWFLAKE_REGION" {
  type = string
}

variable "SANDBOX_SNOWFLAKE_ACCOUNT" {
  type = string
}

provider "snowflake" {
  alias = "sys_admin"
  role = "SYSADMIN"
  region = var.SANDBOX_SNOWFLAKE_REGION
  account = var.SANDBOX_SNOWFLAKE_ACCOUNT
  private_key_path = var.SANDBOX_SNOWFLAKE_PRIVATE_KEY_PATH
  username = var.SANDBOX_SNOWFLAKE_USER
}

resource "snowflake_database" "db" {
  provider = snowflake.sys_admin
  name = "TF_DEMO"
}

resource "snowflake_warehouse" "warehouse" {
  provider = snowflake.sys_admin
  name = "TF_DEMO"
  warehouse_size = "small"
  auto_suspend = 60
}

provider "snowflake" {
  alias = "security_admin"
  role = "SECURITYADMIN"
}

resource "snowflake_role" "role" {
  provider = snowflake.security_admin
  name = "TF_DEMO_SVC_ROLE"
}

resource "snowflake_database_grant" "grant" {
  provider = snowflake.security_admin
  database_name = snowflake_database.db.name
  privilege = "USAGE"
  roles = [snowflake_role.role.name]
  with_grant_option = false
}

resource "snowflake_schema" "schema" {
  provider   = snowflake.sys_admin
  database   = snowflake_database.db.name
  name       = "TF_DEMO"
  is_managed = false
}

resource "snowflake_schema_grant" "grant" {
  provider = snowflake.security_admin
  warehouse_name = snowflake_warehouse.warehouse.name
  privilege = "USAGE"
  roles = [snowflake_role.role.name]
  with_grant_option = false
}

resource "snowflake_warehouse_grant" "grant" {
  provider          = snowflake.security_admin
  warehouse_name    = snowflake_warehouse.warehouse.name
  privilege         = "USAGE"
  roles             = [snowflake_role.role.name]
  with_grant_option = false
}

resource "tls_private_key" "svc_key" {
  algorithm = "RSA"
  rsa_bits = 2048
}

resource "snowflake_user" "user" {
  provider = snowflake.security_admin
  name = "tf_demo_user"
  default_warehouse = snowflake_warehouse.warehouse.name
  default_role = snowflake_role.role.name
  default_namespace = "${snowflake_database.db.name}.${snowflake_schema.schema.name}"
  rsa_public_key = substr(tls_private_key.svc_key.private_key_pem, 27, 398)
}

resource "snowflake_role_grants" "grants" {
  provider = snowflake.security_admin
  role_name = snowflake_role.role.name
  user = [snowflake_user.user.name]
}
