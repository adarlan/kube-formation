variable "instances" {

  type = map(object({
    node_role = string
  }))

  default = {}
}
