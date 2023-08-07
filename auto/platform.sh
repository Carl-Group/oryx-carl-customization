#!/bin/bash

# Execute by: bash xxx.sh or bash zzz/yyy/xxx.sh or ./xxx.sh or ./zzz/yyy/xxx.sh source xxx.sh
REALPATH=$(realpath ${BASH_SOURCE[0]})
SCRIPT_DIR=$(cd $(dirname ${REALPATH}) && pwd)
WORK_DIR=$(cd $(dirname ${REALPATH})/.. && pwd)
echo "BASH_SOURCE=${BASH_SOURCE}, REALPATH=${REALPATH}, SCRIPT_DIR=${SCRIPT_DIR}, WORK_DIR=${WORK_DIR}"
cd ${WORK_DIR}

help=no
refresh=no

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) help=yes; shift ;;
        -refresh|--refresh) refresh=yes; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
done

if [[ "$help" == yes ]]; then
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -h, --help           Show this help message and exit"
    echo "  -refresh, --refresh  Refresh current tag. Default: no"
    exit 0
fi

# We increase version from the v* base.
RELEASE=$(git describe --tags --abbrev=0 --match v*) &&
REVISION=$(echo $RELEASE|awk -F . '{print $3}')
if [[ $? -ne 0 ]]; then echo "Release failed"; exit 1; fi

let NEXT=$REVISION+1
if [[ $refresh == yes && $REVISION != "-1" ]]; then
  let NEXT=$REVISION
fi
echo "Last release is $RELEASE, revision is $REVISION, next is $NEXT"

VERSION="1.0.$NEXT" &&
TAG="v$VERSION" &&
echo "publish version $VERSION as tag $TAG"
if [[ $? -ne 0 ]]; then echo "Release failed"; exit 1; fi

######################################################################
if [[ $(grep -q "const latest = \"$TAG\"" releases/version.go || echo no) == no ]]; then
    echo "Failed: Please update releases/version.go to $TAG"
    echo "    sed -i '' 's|const latest = \".*\"|const latest = \"$TAG\"|g' releases/version.go"
    exit 1
fi
if [[ $(grep -q "const version = \"$TAG\"" platform/version.go || echo no) == no ]]; then
    echo "Failed: Please update platform/version.go to $TAG"
    echo "    sed -i '' 's|const version = \".*\"|const version = \"$TAG\"|g' platform/version.go"
    exit 1
fi

git st |grep -q 'nothing to commit'
if [[ $? -ne 0 ]]; then
  echo "Failed: Please commit before release";
  exit 1
fi

git fetch origin
if [[ $(git status |grep -q 'Your branch is up to date' || echo 'no') == no ]]; then
  git status
  echo "Failed: Please sync before release";
  exit 1
fi
echo "Sync OK"

git fetch gitee
if [[ $(git diff origin/main gitee/main |grep -q diff && echo no) == no ]]; then
  git diff origin/main gitee/main |grep diff
  echo "Failed: Please sync gitee before release";
  exit 1
fi
echo "Sync gitee OK"

######################################################################
git tag -d $TAG 2>/dev/null; git push origin :$TAG 2>/dev/null; git push gitee :$TAG 2>/dev/null
echo "Delete tag OK: $TAG"

git tag $TAG && git push origin $TAG && git push gitee $TAG
echo "Publish OK: $TAG"

echo -e "\n\n"
echo "Publish OK: $TAG $PLATFORM_TAG"
echo "    https://github.com/ossrs/srs-cloud/actions/workflows/platform.yml"
