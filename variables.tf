variable "vpc_id" {
  description = "ID of the existing VPC in us-east-1"
  type        = string
}

variable "existing_public_subnet_id" {
  description = "ID of the existing public subnet in us-east-1a"
  type        = string
}

variable "public_route_table_id" {
  description = "ID of the VPC route table with a default route to the internet gateway"
  type        = string
}
