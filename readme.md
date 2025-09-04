## 定时监控测试延迟
1. doit.sh 放到服务器上
2. 用 crontab 定时执行命令，如五分钟执行一次
3. 定期下载 log.txt
4. 用html可视化查看log

```
chmod +x doit.sh
crontab -e
*/5 * * * * /bin/bash /root/doit.sh
crontab -l
```

## press.sh 压力测试
可以选择不同的线程数量、总请求数量，并且单次运行对系统进行压力测试。
使用方法与 doit.sh  类似，不在讲解。  
log 兼容 html 分析页面。


## curl命令的要求
自定义 curl ：curl 需要在前面增加 `-i` 参数来识别httpcode判断是否200（成功）


## html分析页面
程序提供了一个 index.html ，导入 logl.txt 可以方便的可视化分析日志内容。

<img width="2050" height="1346" alt="图片" src="https://github.com/user-attachments/assets/6e24cba7-cc5e-42c2-ac34-30cc5d8b4890" />


## 声明
此应用的code为ai生成，经过我手工打磨和调教，但是主打一个能用就行。
