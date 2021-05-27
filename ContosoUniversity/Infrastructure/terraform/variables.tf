variable "tags" {
  type = map(any)
  default = {
    "po-number"          = "zzz"
    "environment"        = "dev"
    "mission"            = "demo"
    "protection-level"   = "p1"
    "availability-level" = "a1"
  }
}