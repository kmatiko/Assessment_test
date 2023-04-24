### Instructions
- For this exercise, you will create a free AWS account, and modify the Terraform code in this repo to achieve the goals listed in the bottom section.
- Feel free to utilize any public resource as a reference as you complete the exercise.
- If you encounter any issues, or something is unclear, please try to resolve the issue on your own, or make any reasonable assumptions necessary to make progress independently.  Please note those assumptions as comments in your code.



### Setup
1. Create a free AWS account. You can [create a free account here](https://portal.aws.amazon.com/gp/aws/developer/registration/index.html).
    1. Create an IAM user with AdministratorAccess permissions
    2. Create an access key for that user
    3. Add the credentials in a named profile in `~/.aws/config`, and set the region to `us-east-1`. See the [docs](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html).
2. Create an SSH keypair for the purpose of this exercise.
3. Make sure you have the `terraform` CLI installed.
4. Create a Git repo from the ZIP you received of this repo.
    1. Set the `profile` value in the `provider` block at the top of `main.tf` to match the profile you created in step (1.3).
    2. Change the value of the `ssh_public_key_filename` to point to the public key created in step (2)
    3. Run `terraform init` then `terraform apply` from the root of the repo.
    4. Make sure you can see the created EC2 Instance in the AWS Console for the `us-east-1` region.


### Goals
Some of these will not work without first making modifications to the Terraform code in the repo. While you may want to iterate or debug directly on the EC2 instance, please make sure all changes required to complete the below goals are captured in the Terraform code, and would work when applying the Terraform against an empty AWS account -- a good test, at the end, is to run `terraform destroy` and then `terraform apply` to recreate all the resources in your account.

**Important**: if a step requires you to make changes to network access or IAM permissions, try to grant the least privileges required to complete the step.

1. Make sure you can SSH into your EC2 instance, and that you can visit the running web server in your browser.
    1. Obtain the public IP of the EC2 Instance created -- note: the public IP will change on each instance reboot.
    2. Make sure you can SSH into the EC2 instance using the SSH key you created.
    3. Visit `http://<public IP>` in your browser. You should see the text `Hello World`.
2. Automatically refresh the contents of the `index.html` file, that Nginx serves, from an S3 bucket.
    1. Create an S3 bucket. The bucket should not be publicly accessible.
    2. Make sure that you can access the S3 bucket from your EC2 instance -- do not use static credentials.
    3. Modify the User Data portions of the Terraform code to refresh the contents of the `index.html` file, from some key in the S3 bucket you created, at boot, and every minute after.
3. Using AWS Cloudwatch Agent, stream the Nginx access logs to a Cloudwatch log stream.
    1. By default, the Nginx logs will not be available as a file on the host instance. See the [Dockerfile](https://github.com/nginxinc/docker-nginx/blob/1bacdf4820c8b558e79b8cebb3e6f29c7fc77c17/Dockerfile-debian.template#L93-L94).
    2. The Cloudwatch Agent is already installed, but the configuration file needs to be created, and the agent needs to be started on boot. See the [docs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-Configuration-File-Details.html).
4. Place your instance in a private subnet, and behind an Internet-facing Load Balancer. Your instance should not have a public IP.
5. [Bonus] Create an Autoscaling Group of instances like the single one you have been working with, and put them behind the Load Balancer.
