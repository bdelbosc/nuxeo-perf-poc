# Perf poc
## About

Helper create performance poc deployed in AWS.

## Install

1. Edit your `~/.ssh/config` to use your keypair when accessing AWS, for `eu-west-1`

        Host 52.*
            User ubuntu
            IdentityFile "/home/XXX/.ssh/your-key-pair.pem"


2. Edit `ansible/group_vars/all.yml` to set your keypair and region

3. Make sure your `~/.aws/credentials` is setup with the an AWS account for the region 

4. Install pip3 and virtualenv
   ```bash
   sudo apt install python3-pip
   pip3 install virtualenv
   ```

5. install ansible locally
 
```bash
virtualenv venv
source ./venv/bin/activate
pip3 install -q -r ansible/requirements.txt
```

## Usage

### 1. Provisioning
Allocate all AWS resources.

```bash
./provision.sh
```
### 2. Setup
Configure all instances
```bash
./setup.sh
```
### 3. Start
Start all docker composes
```bash
./start.sh
```
### 4. Pausing and resuming
Stop all AWS instances
```bash
./pause.sh
```

Resume all AWS instances
```bash
./resume.sh
```

### 5. Terminating
Remove all AWS resources (terminating)
```bash
./terminate.sh
```


# About Nuxeo

Nuxeo provides a modular, extensible, open source
[platform for enterprise content management](http://www.nuxeo.com/products/content-management-platform) used by organizations worldwide to power business processes and content repositories in the area of
[document management](http://www.nuxeo.com/solutions/document-management),
[digital asset management](http://www.nuxeo.com/solutions/digital-asset-management),
[case management](http://www.nuxeo.com/case-management) and [knowledge management](http://www.nuxeo.com/solutions/advanced-knowledge-base/). Designed
by developers for developers, the Nuxeo platform offers a modern
architecture, a powerful plug-in model and top notch performance.

More information on: <http://www.nuxeo.com/>
