# Eval_cron_jobs

Before starting make sure some prerequisties to be follow:

Step1: sudo service cron status && sudo service cron start

Step 2: Give the 777 permission to evalcronjob.sh file and create the files nv_eval_pod_logs,pa_eval_pod_logs,va_eval_pod_logs 

step 3: Make sure you have to change the llm_url and service token in the rag and eval yaml files

step 4: Open the crontab -e give the three paramaters(evalconjob.sh,eval_file,logsdirectory,state of dataset)

**Ex**: 0 17 * * * /home/sandeep-vangalapudi/cron_job_evals/evalcronjob.sh /home/sandeep-vangalapudi/cron_job_evals/nv_gt_extract.yaml /home/sandeep-vangalapudi/nv_eval_pod_logs NA >> /home/sandeep-vangalapudi/bashnvsh.log 2>&1

The above commands states that 0 17 means it runs cron job at every 5 pm and 1st parameter is about evalcronjob file and the second parameter is eval_file and the third parameter evallogs files and the fourth parameter is state 

**Note** Have to pass three different eval files and state by overriding the fields in the command.

Step 5:The save and close it will trigger cron job
