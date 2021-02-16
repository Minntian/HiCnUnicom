#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin && export PATH
# Usage:
## wget --no-check-certificate https://raw.githubusercontent.com/mixool/HiCnUnicom/master/CnUnicom.sh && chmod +x CnUnicom.sh && bash CnUnicom.sh membercenter 13800008888@112233 18388880000@123456
### bash <(curl -s https://raw.githubusercontent.com/mixool/HiCnUnicom/master/CnUnicom.sh) membercenter 13800008888@112233 18388880000@123456

# 传入参数格式，支持多账号，手机号@密码必需：13800008888@112233 18388880000@123456
[[ $# != 0 ]] && all_parameter=($(echo $@)) || { echo 'Err  !!! Useage: bash this_script.sh membercenter 13800008888@112233 18388880000@123456'; exit 1; }
all_username_password=($(echo ${all_parameter[*]} | grep -oE "[0-9]{11}@[0-9]{6}"| sort -u | tr "\n" " "))

# 登录失败尝试修改以下这个appId的值为抓包获取的登录过的联通app,也可使用传入参数 appId@*************
appId=247b001385de5cc6ce11731ba1b15835313d489d604e58280e455a6c91e5058651acfb0f0b77029c2372659c319e02645b54c0acc367e692ab24a546b83c302d
echo ${all_parameter[*]} | grep -qE "appId@[a-z0-9]+" && appId=$(echo ${all_parameter[*]} | grep -oE "appId@[a-z0-9]+" | cut -f2 -d@)

# deviceId: 随机IMEI,也可使用传入参数 deviceId@*************
deviceId=$(shuf -i 123456789012345-987654321012345 -n 1)
echo ${all_parameter[*]} | grep -qE "deviceId@[0-9]+" && deviceId=$(echo ${all_parameter[*]} | grep -oE "deviceId@[0-9]+" | cut -f2 -d@)

#####
## 流量激活功能需要传入参数,中间d表示每天,w表示每周一,m代表每月第二天,格式： liulactive@d@ff80808166c5ee6701676ce21fd14716
## 如仅需要部分号码激活流量包时使用参数格式：liulactive@d@ff80808166c5ee6701676ce21fd14716@13012341234-18812341234
## 1GB日包：          ff80808166c5ee6701676ce21fd14716
## 2GB日包:           21010621565413402
## 5GB日包:           21010621461012371
## 10GB日包:          21010621253114290
## 4GB流量七日包:     20080615550312483
## 100MB全国流量月包: ff80808165afd2960165d1eb75424667
## 300MB全国流量月包：ff80808165afd2960165d1e93423464a
## 500MB全国流量月包: ff80808165afd2960165cdbf4a950c1c
## 1GB全国流量月包：  ff80808165afd2960165cdbc92470bef
#####

# 使用Github Action运行时需要传入参数来修改工作路径: githubaction
workdirbase="/var/log/CnUnicom"
echo ${all_parameter[*]} | grep -qE "githubaction" && workdirbase="$(pwd)/CnUnicom"

# 联通APP版本
unicom_version=8.0100

# UA
UA="Mozilla/5.0 (Linux; Android 6.0.1; oneplus a5010 Build/V417IR; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/52.0.2743.100 Mobile Safari/537.36; unicom{version:android@$unicom_version,desmobile:$username};devicetype{deviceBrand:Oneplus,deviceModel:oneplus a5010}"

# alias curl
alias curl='curl -m 10'

################################################################
function rsaencrypt() {
    cat > $workdir/rsa_public.key <<-EOF
-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDc+CZK9bBA9IU+gZUOc6
FUGu7yO9WpTNB0PzmgFBh96Mg1WrovD1oqZ+eIF4LjvxKXGOdI79JRdve9
NPhQo07+uqGQgE4imwNnRx7PFtCRryiIEcUoavuNtuRVoBAm6qdB0Srctg
aqGfLgKvZHOnwTjyNqjBUxzMeQlEC2czEMSwIDAQAB
-----END PUBLIC KEY-----
EOF

    crypt_username=$(echo -n $username | openssl rsautl -encrypt -inkey $workdir/rsa_public.key -pubin -out >(base64 | tr "\n" " " | sed s/[[:space:]]//g))
    crypt_password=$(echo -n $password | openssl rsautl -encrypt -inkey $workdir/rsa_public.key -pubin -out >(base64 | tr "\n" " " | sed s/[[:space:]]//g))
}

function urlencode() {
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf "$c" | xxd -p -c1 | while read x;do printf "%%%s" "$x";done
        esac
    done
}

function userlogin() {
    rsaencrypt
    cat > $workdir/signdata <<-EOF
isRemberPwd=true
&deviceId=$deviceId
&password=$(urlencode $crypt_password)
&simCount=0
&netWay=Wifi
&mobile=$(urlencode $crypt_username)
&yw_code=
&timestamp=$(date +%Y%m%d%H%M%S)
&appId=$appId
&keyVersion=1
&deviceBrand=Oneplus
&pip=10.0.$(shuf -i 1-255 -n 1).$(shuf -i 1-255 -n 1)
&provinceChanel=general
&version=android%40$unicom_version
&deviceModel=oneplus%20a5010
&deviceOS=android6.0.1
&deviceCode=$deviceId
EOF

    # cookie登录
    curl -X POST -sA "$UA" -b $workdir/cookie -c $workdir/cookie "https://m.client.10010.com/mobileService/customer/query/getMyUnicomDateTotle.htm?yw_code=&mobile=$username&version=android%40$unicom_version" | grep -oE "infoDetail" >/dev/null && status=0 || status=1
    [[ $status == 0 ]] && echo && echo $(date) cookies登录${username:0:2}******${username:8}成功
    
    # 账号密码登录
    if [[ $status == 1 ]]; then
        rm -rf $workdir/cookie
        curl -X POST -sA "$UA" -c $workdir/cookie "https://m.client.10010.com/mobileService/logout.htm?&desmobile=$username&version=android%40$unicom_version" >/dev/null
        curl -sA "$UA" -b $workdir/cookie -c $workdir/cookie -d @$workdir/signdata "https://m.client.10010.com/mobileService/login.htm" >/dev/null
        token=$(cat $workdir/cookie | grep -E "a_token" | awk  '{print $7}')
        [[ "$token" = "" ]] && echo && echo $(date) ${username:0:2}******${username:8} Login Failed. && rm -rf $workdir && return 1
        echo && echo $(date) 密码登录${username:0:2}******${username:8}成功
    fi
}


function liulactive() {
    # 流量激活功能
    echo ${all_parameter[*]} | grep -qE "liulactive@[mwd]@[0-9a-z]+" || return 0
    timeparId=$(echo ${all_parameter[*]} | grep -oE "liulactive@[mwd]@[0-9a-z]+" | cut -f2 -d@)
    productId=$(echo ${all_parameter[*]} | grep -oE "liulactive@[mwd]@[0-9a-z]+" | cut -f3 -d@)
    choosenos=$(echo ${all_parameter[*]} | grep -oE "liulactive@[mwd]@[0-9a-z]+@.*" | cut -f4 -d@)
    # 依照参数m|w|d来判断是否执行
    unset liulactive_run
    [[ ${timeparId} == "m" ]] && [[ "$(date +%d)" == "02" ]] && liulactive_run=true
    [[ ${timeparId} == "w" ]] && [[ "$(date +%u)" == "1" ]]  && liulactive_run=true
    [[ ${timeparId} == "d" ]] && liulactive_run=true
    [[ "$liulactive_run" == "true" ]] || return 0
    # 依照参数choosenos来判断是否是指定号码执行,激活功能的参数全格式： liulactive@d@ff80808166c5ee6701676ce21fd14716@13012341234-13112341234
    unset liulactive_only
    [[ $choosenos != "" ]] && echo $choosenos | grep -qE "${username}" && liulactive_only=true
    [[ $choosenos == "" ]] && liulactive_only=true
    [[ "$liulactive_only" == "true" ]] || return 0
    # 激活请求
    echo; echo $(date) liulactive..
    curl -sA "$UA" -b $workdir/cookie -c $workdir/cookie_liulactive "https://m.client.10010.com/MyAccount/trafficController/myAccount.htm?flag=1&cUrl=https://m.client.10010.com/myPrizeForActivity/querywinninglist.htm?pageSign=1" >$workdir/liulactive.log
    liulactiveuserLogin="$(cat $workdir/liulactive.log | grep "refreshAccountTime" | grep -oE "[0-9_]+")"
    curl -sA "$UA" -b $workdir/cookie_liulactive -c $workdir/cookie_liulactive "https://m.client.10010.com/MyAccount/MyGiftBagController/refreshAccountTime.htm?userLogin=$liulactiveuserLogin&accountType=FLOW" >/dev/null
    curl -X POST -sA "$UA"  -b $workdir/cookie_liulactive -c $workdir/cookie_liulactive --data "thirdUrl=thirdUrl=https%3A%2F%2Fm.client.10010.com%2FMyAccount%2FtrafficController%2FmyAccount.htm" https://m.client.10010.com/mobileService/customer/getShareRedisInfo.htm >/dev/null
    Referer="https://m.client.10010.com/MyAccount/trafficController/myAccount.htm?flag=1&cUrl=https://m.client.10010.com/myPrizeForActivity/querywinninglist.htm?pageSign=1"
    curl -X POST -sA "$UA" -e "$Referer" -b $workdir/cookie_liulactive -c $workdir/cookie_liulactive --data "productId=$productId&userLogin=$liulactiveuserLogin&ebCount=1000000&pageFrom=4" "https://m.client.10010.com/MyAccount/exchangeDFlow/exchange.htm?userLogin=$liulactiveuserLogin" | grep -B 1 "正在为您激活"
}

function main() {
    # 签到任务
    for ((u = 0; u < ${#all_username_password[*]}; u++)); do
        sleep $(shuf -i 1-10 -n 1)
        username=${all_username_password[u]%@*} && password=${all_username_password[u]#*@}
        workdir="${workdirbase}_${username}" && [[ ! -d "$workdir" ]] && mkdir $workdir
        userlogin && userlogin_ook[u]=$(echo ${username:0:2}******${username:8}) || { userlogin_err[u]=$(echo ${username:0:2}******${username:8}); continue; }
        liulactive
        #rm -rf $workdir
    done
    echo; echo $(date) ${userlogin_err[*]} ${#userlogin_err[*]} Failed. ${userlogin_ook[*]} ${#userlogin_ook[*]} Accomplished.
    # TG通知
    tgbotinfo
}

main
