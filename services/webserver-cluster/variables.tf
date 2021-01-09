variable "server_port" {
  description = "The port server will use for HTTP requests"
  type        = number 
  default     = 8081
}

variable "cluster_name" {
  description = "The name to use for all the cluster resources"
  type = string
}

variable "db_remote_state_bucket" {
  description = "The name of the S3 bucket for the database's remote state"
  type = string
}

variable "db_remote_state_key" {
  description = "The path for the database's remote state in S3"
  type = string
}

variable "instance_type" {
  description = "Type of EC2 instance to run (e.g. t2.micro)"
  type = string  
}

variable "min_size" {
  description = "Minimum number of EC2 instances in ASG"
  type = number
}

variable "max_size" {
  description = "Maximum number of EC2 instances in ASG"
  type = number
}

#Custom tags to use with for_each loop
variable "custom_tagsy" {
  description = "Custom tags to set on the Instances in ASG"
  type = map(string)
  default = {}
}

#Boolean input variable
variable "enable_autoscaling" {
  description = "If true, enable autoscaling"
  type = bool
}