variable "region" {
    type= string
}

variable "vpc_cidr_block" {
    type= string
}

variable "instance_count" {
  description= "No. of EC2 instances"
  type = number  
}
variable "subnet_cidr_block" {
    type = string
}
variable "instance_image" {
    type=string  
}
variable "instance_type" {
    type=string
}