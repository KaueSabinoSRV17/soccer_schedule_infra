resource "google_firebase_project" "current" {
  provider = google-beta
  project  = var.project_id
}

resource "google_firestore_database" "default" {
  project                     = var.project_id
  name                        = "(default)"
  location_id                 = var.region
  type                        = "FIRESTORE_NATIVE"
  concurrency_mode            = "OPTIMISTIC"
  app_engine_integration_mode = "DISABLED"
  deletion_policy             = "ABANDON"
  delete_protection_state     = "DELETE_PROTECTION_ENABLED"

  depends_on = [google_firebase_project.current]
}
