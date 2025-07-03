variable "aws_region" {
  description = "The AWS region to deploy to."
  type        = string
  default     = "eu-west-1"
}

variable "instance_type" {
  description = "The EC2 instance type."
  type        = string
  default     = "t3.small"
}

variable "openai_api_key_file" {
  description = "Path to the file containing the OpenAI API key."
  type        = string
  default     = "~/.openai"
}

variable "anthropic_api_key_file" {
  description = "Path to the file containing the Anthropic API key."
  type        = string
  default     = "~/.anthropic"
}

variable "gemini_api_key_file" {
  description = "Path to the file containing the Gemini API key."
  type        = string
  default     = "~/.gemini"
}

variable "hostname" {
  description = "The hostname for the server."
  type        = string
  default     = "litellm.joaoanes.website"
}
