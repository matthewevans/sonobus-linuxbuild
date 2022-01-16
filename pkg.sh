#!/bin/bash

#!/bin/bash

ME=${0}
SOURCE="${BASH_SOURCE[0]}"
# resolve $SOURCE until the file is no longer a symlink
while [ -h "$SOURCE" ]; do
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
EXENAME="$( basename "$SOURCE" )"
EXELOC="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

source ${EXELOC}/_mainbody.sh
source ${EXELOC}/_pkgbody.sh

