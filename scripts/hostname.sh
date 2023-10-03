#!/bin/bash
dig +short myip.opendns.com @resolver1.opendns.com | xargs dig +short -x | sed -e 's/.net./.net/'
