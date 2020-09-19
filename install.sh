#!/bin/bash
SH_PATH=$(cd "$(dirname "$0")";pwd)
cd ${SH_PATH}


create_mainfest_file(){
    echo "进行配置。。。"
    read -p "请输入你的应用名称：" IBM_APP_NAME
    echo "应用名称：${IBM_APP_NAME}"
    config_restart ${IBM_APP_NAME}
    read -p "请输入你的应用内存大小(默认256)：" IBM_MEM_SIZE
    if [ -z "${IBM_MEM_SIZE}" ];then
    IBM_MEM_SIZE=256
    fi
    echo "内存大小：${IBM_MEM_SIZE}"
    UUID=$(cat /proc/sys/kernel/random/uuid)
    echo "生成随机UUID：${UUID}"

    WSPATH=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
    echo "生成随机WebSocket路径：${WSPATH}"
    
    cat >  ${SH_PATH}/IBMYes/demo-cloudfoundry/manifest.yml  << EOF
    applications:
    - path: .
      name: ${IBM_APP_NAME}
      random-route: true
      memory: ${IBM_MEM_SIZE}M
EOF

    sed -i 's/UUID/'"$UUID"'/g' ${SH_PATH}/IBMYes/template.json
    sed -i 's/WSPATH/'"$WSPATH"'/g' ${SH_PATH}/IBMYes/template.json
    cat ${SH_PATH}/IBMYes/template.json | base64 > ${SH_PATH}/IBMYes/demo-cloudfoundry/demo/test
    echo "base64 str is "
    cat ${SH_PATH}/IBMYes/demo-cloudfoundry/demo/test
    echo "配置完成。"
}

config_restart(){

   echo "请务必确认用户名称和密码正确，否则可能导致无法重启！！！"
    read -p "请输入你的用户名：" IBM_User_NAME
    echo "用户名称：${IBM_User_NAME}"
    read -p "请输入你的密码：" IBM_Passwd
    echo "用户密码：${IBM_Passwd}"
    ibmcloud login -a "https://cloud.ibm.com" -r "us-south" -u "${IBM_User_NAME}" -p "${IBM_Passwd}"

    # 配置预启动文件
    cat >  ${SH_PATH}/IBMYes/demo-cloudfoundry/start.sh  << EOF
      #!/bin/bash
      chmod -R 777 ./demo &&  cat ./demo/test  &&  cat ./demo/test | base64 -d > ./demo/config.json  &&  ./demo/demo

      ./demo/demo &
      sleep 4d

      ./cf l -a https://api.us-south.cf.cloud.ibm.com login -u "${IBM_User_NAME}" -p "${IBM_Passwd}"

      ./cf rs $1
EOF

}

clone_repo(){
    echo "进行初始化。。。"
	  rm -rf IBMYes
    git clone https://github.com/hashiqi12138/IBMYes
    cd IBMYes
    git submodule update --init --recursive
    cd demo-cloudfoundry/demo

    echo "初始化完成。"
}

install(){
    echo "进行安装。。。"
    cd ${SH_PATH}/IBMYes/demo-cloudfoundry
    ibmcloud target --cf
    echo "N"|ibmcloud cf install
    # 获取路由地址
    ROUTES=$( ibmcloud cf push | awk '$1=="routes:" &&  $2!="" {print $2}'| awk 'NR==1' )
    echo "获取的路由地址为： ${ROUTES}"
#    ibmcloud cf push
    echo "安装完成。"
    echo "生成的随机 UUID：${UUID}"
    echo "生成的随机 WebSocket路径：${WSPATH}"
    VMESSCODE=$(base64 -w 0 << EOF
    {
      "v": "2",
      "ps": "${IBM_APP_NAME}",
      "add": "cloudflare.com",
      "port": "8080",
      "id": "${UUID}",
      "aid": "64",
      "net": "ws",
      "type": "none",
      "host": "${ROUTES}",
      "path": "${WSPATH}",
      "tls": "tls"
    }
EOF
    )
	echo "配置链接："
    echo vmess://${VMESSCODE}

}

clone_repo
create_mainfest_file
install
exit 0