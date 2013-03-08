# Librarian-EC2

Shell scipts to provision an EC2 instance from an existing Vagrantfile ([Vagrant](http://vagrantup.com)) and Cheffile ([Librarian](https://github.com/applicationsonline/librarian)) config files.

This project is inspired by [vagrant-ec2](https://github.com/lynaghk/vagrant-ec2/) (and [vagrant-ec2-r](https://github.com/wch/vagrant-ec2-r)) but works with coobooks with dependencies by relying on [Librarian](https://github.com/applicationsonline/librarian).

It's an easy solution for provisionning and EC2 instance.

These scripts have been tested only on Mac OS X 10.7 but should works on many unix based system, and if it's note the case, the script is simple fix it and make a pull request ;)

## Requirements

* [VirtualBox 4](http://www.virtualbox.org/wiki/Downloads)
* [Vagrant](http://vagrantup.com) (`gem install vagrant`)
* [Librarian](https://github.com/applicationsonline/librarian) (`gem install librarian`)
* [EC2 API Tools](http://aws.amazon.com/developertools/351)

## Introduction to Vagrant and Librarian
If you need an developer-centric introduction to Vagrant and Librarian please refer to my posts on tumblr [tumblr.nrako.com/tagged/vagrant](http://tumblr.nrako.com/tagged/vagrant).

## Provisoning EC2

### Requirements

On your local machine, you will need the following:

* [AWS EC2 API Tools](http://aws.amazon.com/developertools/3519) installed and setup, try [google](https://www.google.com/search?q=setup+aws+ec2+api+tools) to find help for the setup.
* The JSON Ruby gem:

  ```
  gem install --user-install json
  ```

* Create a key pair in the appropriate region if you don't have one. In our example the region is `us-west-1`, and we'll use the name `ec2-us-west-1-keypair`:

  ```
  ec2-add-keypair --region us-west-1 ec2-us-west-1-keypair > ~/.ec2/ec2-us-west-1-keypair
  chmod 600 ~/.ec2/ec2-us-west-1-keypair
  ```

  Note : ubuntu on us-east-1 has some [temporary issue as today (29th Mai 2012)](https://forums.aws.amazon.com/thread.jspa?threadID=95616)


### Create and provision an EC2 instance machine

Do the following each time you want to create a virtual machine on EC2.

Start up a new EC2 instance (`ami-87712ac2` is a Ubuntu 12.04 64-bit server in region `us-west-1`):

    ec2-run-instances ami-87712ac2 --region us-west-1 --instance-type t1.micro --key ec2-us-west-1-keypair --user-data-file bootstrap.sh

Note that `--user-data-file boostrap.sh` is important as it will install Chef-solo and Librarian and you may want to add `-g <your security group>`.

Find its IP address with:

    ec2-describe-instances --region us-west-1

After the machine boots up, provision it using the same recipes as the demo Vagrant machine machine:

    ./setup.sh <ip address> path_to_vagrantfile/ ~/.ec2/ec2-us-west-1-keypair

This will `scp` secure copy Cheffile and dna.json to the EC2 instance, run `librarian-chef install` to fetch the recipes and run `chef-solo`.

It should print a lot of diagnostic info to the terminal. If it doesn't, wait a little while and try again.

You can ssh into the machine:

    ssh -i ~/.ec2/ec2-us-west-1-keypair ubuntu@<ip address>

This will terminate your instances when you're finished:

    ec2-terminate-instances --region us-west-1 <i-instance_id>


### Converting existing Vagrantfiles

Just add six lines in the provisioning section of your `Vagrantfile` so it looks like this:

    config.vm.provision :chef_solo do |chef|

      <your provisioning here>

      # Generate the dna.json file used to describe the recipes to be executed by chef-solo on ec2
      require 'json'
      open('dna.json', 'w') do |f|
        chef.json[:run_list] = chef.run_list
        f.write chef.json.to_json
      end
    end


## Credits
Inspired by [vagrant-ec2-r](https://github.com/wch/vagrant-ec2-r) from Winston Chang.
Which is based on [vagrant-ec2](https://github.com/lynaghk/vagrant-ec2/) from Keming labs.
[Librarian](https://github.com/applicationsonline/librarian) from Jay Feldblum.