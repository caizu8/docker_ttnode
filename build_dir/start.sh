#!/bin/bash
if [ -f "/.dockerenv" ]; then
	CONFIG_DIR="/config"
else
	CONFIG_DIR=$(dirname $0)
fi

function move_config() {
	OLD_DIR=$(dirname $0)
	if [[ $OLD_DIR != $CONFIG_DIR ]]; then
		mkdir -p "$CONFIG_DIR"
		f="crontab_list.sh"
		if [ -f "$OLD_DIR/$f" ]; then
			if [ ! -f "$CONFIG_DIR/$f" ]; then
				cp "$OLD_DIR/$f" "$CONFIG_DIR/$f"
			fi
			mv "$OLD_DIR/$f" "$OLD_DIR/$f.bak"
			echo "迁移$OLD_DIR/$f到$CONFIG_DIR/$f"
		fi
	fi
}

if [[ $DISABLE_ATUO_TASK != "1" ]]; then
	service cron start
	move_config
	if [ ! -f "$CONFIG_DIR/crontab_list.sh" ]; then
		echo '0 0 * * *  /usr/node/ttnode_task.sh update' >$CONFIG_DIR/crontab_list.sh
		echo '8 4 * * *  /usr/node/ttnode_task.sh report' >>$CONFIG_DIR/crontab_list.sh
		echo '15 4 * * 3 /usr/node/ttnode_task.sh withdraw' >>$CONFIG_DIR/crontab_list.sh
	fi
	crontab $CONFIG_DIR/crontab_list.sh
fi

foundport=0
last=$(date +%s)
while true; do
	num=$(ps fax | grep '/ttnode' | egrep -v 'grep|echo|rpm|moni|guard' | wc -l)
	if [ $num -lt 1 ]; then
		d=$(date '+%F %T')
		echo "[$d] ttnode进程不存在,启动ttnode"
		case "$(uname -m)" in
		x86_64)
			qemu="/usr/bin/qemu-arm-static"
			;;
		aarch64)
			qemu=""
			;;
		armv7l)
			qemu=""
			;;
		*)
			echo "不支持的处理器平台!!!"
			exit 1
			;;
		esac
		$qemu /usr/node/ttnode -p /mnts
		/usr/node/qr.sh

		# sleep 20
		# num=`ps fax | grep '/ttnode' | egrep -v 'grep|echo|rpm|moni|guard' | wc -l`;
		# if [ $num -lt 1 ];then
		# d=`date '+%F %T'`;
		# echo "[$d] ttnode启动失败,再来一次"
		# /usr/node/ttnode -p /mnts
		# fi
	fi

	if [ $foundport -eq 0 ]; then
		netstat -nlp | grep "$(ps fax | grep '/ttnode' | egrep -v 'grep|echo|rpm|moni|guard' | awk '{print $1}')/" | grep -v '127.0.0.1\|17331' | awk '{sub(/0.0.0.0:/,""); print $1,$4}' | sort -k 2n -k 1 >/usr/node/port.txt
		len=$(sed -n '$=' /usr/node/port.txt)
		if [[ $len -gt 4 ]]; then
			echo "==========================================================================="
			d=$(date '+%F %T')
			echo "[$d] 如果UPNP失效，请在路由器上对下列端口做转发"
			cat /usr/node/port.txt | awk '{print $1,$2" "}'
			# awk '{x[$2]=x[$2]" "$1} END {for(i in x){print i x[i]}}' /usr/node/port.txt |awk '{print $2","$3,$1" "}'|sed 's/, / /'
			echo "==========================================================================="
			foundport=1
			last=$(date +%s)
		else
			d=$(date '+%F %T')
			echo "[$d] 正在获取端口信息..."
		fi
	fi

	if [ $foundport -eq 0 ]; then
		sleep 20
	else
		sleep 60
		now=$(date +%s)
		diff=$(($now - $last))
		if [[ $diff -gt 43200 ]]; then #12 hour
			foundport=0
		fi
	fi
done
