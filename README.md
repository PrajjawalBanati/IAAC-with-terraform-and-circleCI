# Terraform and CircleCI

- CircleCI is a continuous integration tool for automation of software builds, tests, and deployments. The continuous integration workflow enables development teams to automate, self-test, quickly build, clone, and deploy software. 
- Terraform allows for repeatable infrastructure deployment and by adding Terraform into a CircleCI workflow, you can deploy your infrastructure alongside software in the same pipeline.
- In this guide you will use CircleCI to deploy Terraform-managed-infrastructure that creates a VPC, a subnet, a security group and 2 EC2 instances. It will be provisioned by Terraform and workflow will be confirmed by CircleCI.
- You should review the [CircleCI getting started guide](https://circleci.com/docs/2.0/about-circleci/#section=welcome), sign up and try CircleCI.
- This guide assumes you have the following:
  - A [GitHub account](https://github.com/join?source=header-home)
  - A [CircleCI account](https://circleci.com/signup/). Sign up with your GitHub account so CircleCI can build and deploy from your GitHub repositories.
  - A [Terraform Cloud account](https://app.terraform.io/)
  - An [AWS account](https://aws.amazon.com/account/)

## Analyse a CircleCI configuration

- First, review some of the CircleCI keywords.

  - **Steps** are actions that CircleCI takes in the workflow to perform your job. Steps are usually a collection of executable commands. For example, the checkout step checks out the source code for a job over SSH. Then, the run step executes the make test command using a non-login shell by default.
  - **Jobs** are collections of steps. Each job must declare an executor, an operating system which will launch and perform the actions you define, and a series of steps. This can be either `docker`, `machine`, `windows` or `macos`. You will use the `docker` executor in this guide.
  - **Workspaces** are a storage mechanism within CircleCI. The workspace stores data needed for downstream jobs, which can be useful for persisting state in Terraform.
  - **Workflows** define a list of jobs and their run order. It is possible to run jobs in parallel, sequentially, on a schedule, or with a manual gate using an approval job.

- Below shown is the first section of the `config.yml`. This starting configuration defines `references` to default base images, working directories, and default configurations for your containers. Our `default_config` reference downloads the latest [Terraform Docker image](https://hub.docker.com/r/hashicorp/terraform) from the HashiCorp Docker Hub.

  ``` yml
  version: 2
  
  references:
  
  base_image: &base_image hashicorp/terraform:light
  
  working_directory: &working_directory ~/project
  
  default_config: &default_config
    docker:
      - image: *base_image
    working_directory: *working_directory
    environment:
      BASH_ENV: /root/.bashrc
      TERRAFORM_ENV: ~/project/
  
  repo_cache_key: &repo_cache_key v1-repo-{{ .Branch }}-{{ .Revision }}
  	
  ```

- Because you are running plan, apply, and destroy jobs that take place in different containers, `restore_repo` and `save_repo` allow you to restore the repository from cache into the containers.

  ```yaml
  # Step to restore repository from cache
  restore_repo: &restore_repo
    restore_cache:
      key: *repo_cache_key
  
  save_repo: &save_repo
    save_cache:
      key: *repo_cache_key
      paths:
        - *working_directory
  
  ```

- This portion of the config sets the Terraform environment for the running containers. The `TF_API_TOKEN` is a Terraform Cloud environment variable CircleCI needs to operate on your behalf in the workflow.

  ```yaml
  set_terraform_environment: &set_terraform_environment
    run:
      name: set terraform environment
      command: |
        cd && touch $BASH_ENV
        cd ~/project/
  terraform_init: &terraform_init
    run:
      name: terraform init
      command: |
        source $BASH_ENV
        cd ~/project/
        terraform init -backend-config="token=${TF_API_TOKEN}"
  
  ```

- Once the image is successfully pulled, CircleCI runs the actions defined by `steps` in the `jobs` section.

- The five jobs associated with this configuration are `init`, `plan`, `apply`, and `destroy`. Look at the `plan` job as an example. In `plan`, the steps to run `terraform plan` restore the repo to the new directory, set the environment to which the Terraform command will run, initialize the Terraform directory and then run `terraform plan` before continuing to the apply phase.

  ```yaml
  jobs:
  
    build:
      <<: *default_config
      steps:
        - checkout
        - *set_terraform_environment
        - run:
            name: terraform fmt
            command: |
              source $BASH_ENV
              cd ~/project/
              terraform init -backend-config="token=${TF_API_TOKEN}"
              terraform fmt
        - *save_repo
  
    plan:
      <<: *default_config
      steps:
        - *restore_repo
        - *set_terraform_environment
        - *terraform_init
        - run:
            name: terraform plan
            command: |
              source $BASH_ENV
              cd ~/project/
              terraform plan
    apply:
      <<: *default_config
      steps:
        - *restore_repo
        - *set_terraform_environment
        - *terraform_init
        - run:
            name: terraform apply
            command: |
              source $BASH_ENV
              cd ~/project/
              terraform apply -auto-approve
    
    destroy:
      <<: *default_config
      steps:
        - *restore_repo
        - *set_terraform_environment
        - *terraform_init
        - run:
            name: "Destruction of env"
            command: |
              source $BASH_ENV
              cd ~/project/
              terraform destroy -auto-approve
  ```

- Finally, the last block in the configuration is the `workflows`. Workflow defines order, precedence, and requirements to perform the jobs within the pipeline. 

  ```yaml
  workflows:
    version: 2
    build_plan_approve_apply:
      jobs:
        - build
        - plan:
            requires:
              - build
        - apply:
            requires:
              - plan
        - destroy:
            requires:
              - apply
  ```

## Setup The Terraform Cloud

- In your Terraform Cloud account, navigate to the user settings by clicking on your profile logo and then click on tokens and click on `Create an API token`. Give the description as `circleci` and create an API token.

- Copy that token and store it somewhere because this token will be needed to connect CircleCI with Terraform Cloud.

- Then go to your organisation and create a new workspace and this time choose `No VCS connection` name the workspace as `learn-terraform-circleci`. After the workspace is created  click on your newly created workspace and go to `variables` section and create the following variables as given below.

  | Key               | Value                 |
  | ----------------- | --------------------- |
  | region            | us-east-1             |
  | instance_image    | ami-0915e09cc7ceee3ab |
  | instance_type     | t2.micro              |
  | subnet_cidr_block | 10.0.1.0/24           |
  | vpc_cidr_block    | 10.0.0.0/16           |
  | instance_count    | 1                     |

  In Environment Variables, enter your AWS-Credential keys. 

  - [`AWS_ACCESS_KEY_ID`](https://learn.hashicorp.com/terraform/development/circle#aws_access_key_id) Set as sensitive.
  - [`AWS_SECRET_ACCESS_KEY`](https://learn.hashicorp.com/terraform/development/circle#aws_secret_access_key) Set as sensitive.
  - [`CONFIRM_DESTROY`](https://learn.hashicorp.com/terraform/development/circle#confirm_destroy) This is necessary for CircleCI to run destroy operations when the operator decides to destroy the application. Set this to `1`.sxamx
  
- The pre-work for setting up CircleCI is complete and now you can kick off a run for your infrastructure. Start by updating your code in the GitHub repository.

## Setup the CircleCI UI

- Create a repository on GitHub having the following files. 

  ```bash
  tree -a
  .
  ├── .circleci
  │   └── config.yml
  ├── remote.tf
  ├── resources.tf
  └── variables.tf
  ```

- The `resources.tf` configuration is what CircleCI will run on your behalf. In order to pass this configuration to the CircleCI jobs, you have to setup your CirleCI project. 

  ```hcl
  provider "aws" {
      region="${var.region}" 
  }
  
  resource "aws_vpc" "module_vpc" {
    cidr_block = "${var.vpc_cidr_block}"
  }
  
  resource "aws_subnet" "module_subnet" {
    vpc_id     = "${aws_vpc.module_vpc.id}"
    cidr_block = "${var.subnet_cidr_block}"
  }
  
  resource "aws_security_group" "all" {
    name        = "all"
    description = "Allow all inbound traffic"
    vpc_id      = "${aws_vpc.module_vpc.id}"
  
    ingress {
      description = "all VPC"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  
    egress {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  
    tags = {
      Name = "allow_ssh"
    }
  }
  
  resource "aws_instance" "testInstance" {
    ami           = "${var.instance_image}"
    instance_type = "t2.micro"
    count = var.instance_count
    vpc_security_group_ids = ["${aws_security_group.all.id}"]  
    associate_public_ip_address=true
    subnet_id="${aws_subnet.module_subnet.id}"
    connection {
      host        = coalesce(self.public_ip,self.private_ip)
      type        = "ssh"
      user        = "ec2-user"
      password    = ""
    }
    }
  ```

- Design `remote.tf` file which will initialise the Terraform Backend.

  ```hcl
  terraform {
    backend "remote" {
      organization = "<YOUR ORGANISATION NAME>"
  
      workspaces {
        name = "learn-terraform-circleci"
      }
    }
  }
  ```

- Design `variable.tf` and intialize the variables.

  ```hcl
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
  ```

- A glimpse of the above discussed `config.yml`.

  ```yaml
  version: 2
  
  references:
  
  base_image: &base_image hashicorp/terraform:light
  
  working_directory: &working_directory ~/project
  
  default_config: &default_config
    docker:
      - image: *base_image
    working_directory: *working_directory
    environment:
      BASH_ENV: /root/.bashrc
      TERRAFORM_ENV: ~/project/
  
  repo_cache_key: &repo_cache_key v1-repo-{{ .Branch }}-{{ .Revision }}
  # Step to restore repository from cache
  restore_repo: &restore_repo
    restore_cache:
      key: *repo_cache_key
  
  save_repo: &save_repo
    save_cache:
      key: *repo_cache_key
      paths:
        - *working_directory
  set_terraform_environment: &set_terraform_environment
    run:
      name: set terraform environment
      command: |
        cd && touch $BASH_ENV
        cd ~/project/
  terraform_init: &terraform_init
    run:
      name: terraform init
      command: |
        source $BASH_ENV
        cd ~/project/
        terraform init -backend-config="token=${TF_API_TOKEN}"
  jobs:
  
    build:
      <<: *default_config
      steps:
        - checkout
        - *set_terraform_environment
        - run:
            name: terraform fmt
            command: |
              source $BASH_ENV
              cd ~/project/
              terraform init -backend-config="token=${TF_API_TOKEN}"
              terraform fmt
        - *save_repo
  
    plan:
      <<: *default_config
      steps:
        - *restore_repo
        - *set_terraform_environment
        - *terraform_init
        - run:
            name: terraform plan
            command: |
              source $BASH_ENV
              cd ~/project/
              terraform plan
    apply:
      <<: *default_config
      steps:
        - *restore_repo
        - *set_terraform_environment
        - *terraform_init
        - run:
            name: terraform apply
            command: |
              source $BASH_ENV
              cd ~/project/
              terraform apply -auto-approve
    
    destroy:
      <<: *default_config
      steps:
        - *restore_repo
        - *set_terraform_environment
        - *terraform_init
        - run:
            name: "Destruction of env"
            command: |
              source $BASH_ENV
              cd ~/project/
              terraform destroy -auto-approve
  workflows:
    version: 2
    build_plan_approve_apply:
      jobs:
        - build
        - plan:
            requires:
              - build
        - apply:
            requires:
              - plan
        - destroy:
            requires:
              - apply
  ```

- Push your code into the GitHub repo (all these files).

- In the CircleCI web UI, add a new project.

  ![](https://github.com/PrajjawalBanati/learn-terraform-circleci/blob/master/Outputs/1-Add-Your-Project.png)

- Search for the repo you pushed and choose Set Up Project. Choose "Hello World" as the language and ignore the sample `.yml` file generated.

  ![](https://github.com/PrajjawalBanati/learn-terraform-circleci/blob/master/Outputs/2-Setup-Project.png)

  ![](https://github.com/PrajjawalBanati/learn-terraform-circleci/blob/master/Outputs/3-Start-Building.png)

  ![](https://github.com/PrajjawalBanati/learn-terraform-circleci/blob/master/Outputs/4-Add-Manually.png)

- Choose "Start Building" and you should be presented with a popup confirming you have created `config.yml` file.

  ![](https://github.com/PrajjawalBanati/learn-terraform-circleci/blob/master/Outputs/Start-Building.png)

- It will fail because the Environment Variables are not set and are necessary to run the correct jobs.

  ![](https://github.com/PrajjawalBanati/learn-terraform-circleci/blob/master/Outputs/Failed.png)

- In the right hand corner of this page, find the gear icon to be taken to the project settings and choose environment variables from Build Settings.

- The four environment variables for this project are `APP_BUCKET`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `TF_API_TOKEN`. These are variables that CircleCI uses to inject data into the `.config.yml` file.

  ![](https://github.com/PrajjawalBanati/learn-terraform-circleci/blob/master/Outputs/7-Environment%20Variables.png)

- Commit a small change in GitHub this will push a change and thus you pipeline will run. So here are the small glimpses of all the stages which ran successfully.

- Running Pipeline

  ![](https://github.com/PrajjawalBanati/learn-terraform-circleci/blob/master/Outputs/running.png)
- Build Successfull
  ![](https://github.com/PrajjawalBanati/learn-terraform-circleci/blob/master/Outputs/buildsucces.png)
- Plan Successfull
  ![](https://github.com/PrajjawalBanati/learn-terraform-circleci/blob/master/Outputs/plansuccessfull.png)
- Apply successfull
  ![](https://github.com/PrajjawalBanati/learn-terraform-circleci/blob/master/Outputs/applysuccessfu.png)
- Destroy successfull
  ![](https://github.com/PrajjawalBanati/learn-terraform-circleci/blob/master/Outputs/destroy.png)
- Pipeline Successfull
  ![](https://github.com/PrajjawalBanati/learn-terraform-circleci/blob/master/Outputs/pipeline%20successfull.png)

## Hold Stage

- So it will run `build plan apply destroy` in one pipeline. Now what we want is that the pipeline runs successfully till apply and then it remains on hold. So for that we have to add `hold` step in the workflow. 

- A `hold` step will prevent CircleCI from continuing to the next job in your workflow. he `hold` step is placed before `destroy`, which runs `terraform destroy` in our workspace, and allows you to decide when to move to the final step in the configuration.

- So add `hold` step in your `config.yml` and commit the file.

  ```yaml
  workflows:
    version: 2
    build_plan_approve_apply:
      jobs:
      [...]#After apply step
      - hold:
      	type: approval
      	requires:
      		- apply
      - destroy:
      	requires:
      		-hold
  ```

- Commit this code snippet to github and again your pipeline will start. This time after `plan`,`apply`, it will remain on hold and will ask for approval from the user. 

  ![](https://github.com/PrajjawalBanati/learn-terraform-circleci/blob/master/Outputs/running%20again.png)

  ![](https://github.com/PrajjawalBanati/learn-terraform-circleci/blob/master/Outputs/on-hold.png)

- Click on the tab and then `Approve` the destruction. And so it will run the destruction step after your approval. And so will pipeline will run successfully.
- On hold
  ![](https://github.com/PrajjawalBanati/learn-terraform-circleci/blob/master/Outputs/approve.png)
- Approve Hold
  ![](https://github.com/PrajjawalBanati/learn-terraform-circleci/blob/master/Outputs/approval-success.png)
- Running Destroy after Approving 
  ![](https://github.com/PrajjawalBanati/learn-terraform-circleci/blob/master/Outputs/running-destroy.png)
- Pipeline Successfull
  ![](https://github.com/PrajjawalBanati/learn-terraform-circleci/blob/master/Outputs/approval-success.png)

So It was all about automating terraform with CircleCI.
