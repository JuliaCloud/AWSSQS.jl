#==============================================================================#
# AWSSQS.jl
#
# SQS API. See http://aws.amazon.com/documentation/sqs/
#
# Copyright Sam O'Connor 2014 - All rights reserved
#==============================================================================#


module AWSSQS

__precompile__()

export sqs_list_queues, sqs_get_queue, sqs_create_queue, sqs_delete_queue, 
       sqs_send_message, sqs_send_message_batch, sqs_receive_message,
       sqs_delete_message, sqs_flush, sqs_get_queue_attributes, sqs_count,
       sqs_busy_count


using AWSCore
using SymDict
using Retry

import Nettle: digest, hexdigest
import URIParser: URI


sqs_name(q) = split(q[:resource], "/")[3]
sqs_arn(q) = arn(q, "sqs", sqs_name(q))


function sqs(aws, query)
    query["ContentType"] = "JSON"
    do_request(post_request(aws, "sqs", "2012-11-05", query))
end

sqs(aws; args...) = sqs(aws, StringDict(args))


function sqs_list_queues(aws, prefix="")

    r = sqs(aws, Action="ListQueues", QueueNamePrefix = prefix)
    if r["queueUrls"] == nothing
        return []
    else
        return [merge(aws, resource = URI(url).path) for url in r["queueUrls"]]
    end
end

# SQS Queue Lookup.
# Find queue URL.
# Return a revised "aws" dict that captures the URL path.

function sqs_get_queue(aws, name)

    @protected try

        r = sqs(aws, Action="GetQueueUrl", QueueName = name)
        url = r["QueueUrl"]
        return merge(aws, resource = URI(url).path)

    catch e
        @ignore if e.code == "AWS.SimpleQueueService.NonExistentQueue" end
    end

    return nothing
end


# Create new queue with "name".
# options: VisibilityTimeout, MessageRetentionPeriod, DelaySeconds etc
# See http://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_CreateQueue.html

function sqs_create_queue(aws, name; options...)

    println("""Creating SQS Queue "$name"...""")

    query = Dict(
        "Action" => "CreateQueue",
        "QueueName" => name
    )
    
    for (i, (k, v)) in enumerate(options)
        query["Attribute.$i.Name"] = k
        query["Attribute.$i.Value"] = v
    end

    @repeat 4 try

        url = sqs(aws, query)["QueueUrl"]
        return merge(aws, resource = URI(url).path)

    catch e

        @retry if e.code == "QueueAlreadyExists"
            sqs_delete_queue(aws, name)
        end

        @retry if e.code == "AWS.SimpleQueueService.QueueDeletedRecently"
            println("""Waiting 1 minute to re-create Queue "$name"...""")
            sleep(60)
        end
    end

    assert(false) # Unreachable.
end


function sqs_delete_queue(queue)

    @protected try

        println("Deleting SQS Queue $(sqs_name(queue))")
        sqs(queue, Action="DeleteQueue")

    catch e
        @ignore if e.code == "AWS.SimpleQueueService.NonExistentQueue" end
    end
end


function sqs_send_message(queue, message)

    sqs(queue, Action="SendMessage",
               MessageBody = message,
               MD5OfMessageBody = string(digest("md5", message)))
end


function sqs_send_message_batch(queue, messages)

    batch = Dict()
    
    for (i, message) in enumerate(messages)
        batch["SendMessageBatchRequestEntry.$i.Id"] = i
        batch["SendMessageBatchRequestEntry.$i.MessageBody"] = message
    end
    sqs(queue, Action="SendMessageBatch", Attributes=batch)
end


function sqs_receive_message(queue)

    r = sqs(queue, Action="ReceiveMessage", MaxNumberOfMessages = "1")
    r = r["messages"]
    if r == nothing
        return nothing
    end

    handle  = r[1]["ReceiptHandle"]
    message = r[1]["Body"]
    md5     = r[1]["MD5OfBody"]

    @assert md5 == hexdigest("md5", message)

    @SymDict(message, handle)
end

type AWSSQSMessages queue end

sqs_messages(queue) = AWSSQSMessages(queue)
Base.eltype(::AWSSQSMessages) = Dict{Symbol,Any}
Base.start(::AWSSQSMessages) = nothing
Base.done(::AWSSQSMessages, ::Any) = false
Base.next(q::AWSSQSMessages, ::Any) = (sqs_receive_message(q.queue), nothing)


function sqs_delete_message(queue, message)

    sqs(queue, Action="DeleteMessage", ReceiptHandle = message[:handle])
end


function sqs_flush(queue)

    while (m = sqs_receive_message(queue)) != nothing
        sqs_delete_message(queue, m)
    end
end


function sqs_get_queue_attributes(queue)

    @protected try

        r = sqs(queue, Dict("Action" => "GetQueueAttributes",
                            "AttributeName.1" => "All"))

        return [i["Name"] => i["Value"] for i in r["Attributes"]]

    catch e
        @ignore if e.code == "AWS.SimpleQueueService.NonExistentQueue" end
    end

    return nothing
end


function sqs_count(queue)
    
    parse(Int,sqs_get_queue_attributes(queue)["ApproximateNumberOfMessages"])
end


function sqs_busy_count(queue)
    
    parase(Int,sqs_get_queue_attributes(queue)["ApproximateNumberOfMessagesNotVisible"])
end



end # module AWSSQS



#==============================================================================#
# End of file.
#==============================================================================#

