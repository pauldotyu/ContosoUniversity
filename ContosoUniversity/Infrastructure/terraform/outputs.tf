output "password" {
  value     = random_password.cu.result
  sensitive = true
}