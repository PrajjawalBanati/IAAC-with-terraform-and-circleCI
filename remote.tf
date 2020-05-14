terraform {
  backend "remote" {
    organization = "xebia-intern-2020"

    workspaces {
      name = "learn-terraform-circleci"
    }
  }
}