terraform {
  backend "remote" {
    organization = "jonbamber"

    workspaces {
      name = "personal-website"
    }
  }
}
