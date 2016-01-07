# AWSSQS

AWS SQS Interface for Julia

[![Build Status](https://travis-ci.org/samoconnor/AWSSQS.jl.svg)](https://travis-ci.org/samoconnor/AWSSQS.jl)

```julia
using AWSSQS

aws = AWSCore.aws_config()

q = sqs_get_queue(aws, "my-queue")

sqs_send_message(q, "Hello!")

m = sqs_receive_message(q)
println(m[:message])
sqs_delete_message(q, m)

for m in sqs_messages(q)
    println(m[:message])
    sqs_delete_message(q, m)
end
```
