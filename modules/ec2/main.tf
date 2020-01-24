resource "aws_instance" "demo" {
  ami           = "ami-0d5d9d301c853a04a"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  count = 5
}
