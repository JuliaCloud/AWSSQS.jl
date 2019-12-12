create_queue(; queue_name="ocaws-jl-test-queue-" * lowercase(Dates.format(now(Dates.UTC), "yyyymmddTHHMMSSZ"))) = sqs_create_queue(aws, queue_name)

function cleanup_queues()
    for q in sqs_list_queues(aws, "ocaws-jl-test-queue-")
        sqs_delete_queue(q)
    end
end

@testset "Queue" begin
    @testset "Create Queue" begin
        queue_name = "ocaws-jl-test-queue-" * lowercase(Dates.format(now(Dates.UTC), "yyyymmddTHHMMSSZ"))
        created_queue = create_queue(queue_name=queue_name)
        fetched_queue = sqs_get_queue(aws, queue_name)

        @test created_queue[:resource] == fetched_queue[:resource]
    end

    @testset "Send Message" begin
        queue = create_queue()
        sqs_send_message(queue, "Hello!")
        message = sqs_receive_message(queue)

        @test message[:message] == "Hello!"
    end

    @testset "Send Batch Messages" begin
        queue = create_queue()
        num_messages = 10

        msgs = repeat(["test message"], outer=num_messages)
        sqs_send_message_batch(queue, msgs)
        message_count = sqs_count(queue)

        @test message_count == num_messages
    end

    @testset "Queue Attributes" begin
        queue = create_queue()
        info = sqs_get_queue_attributes(queue)

        @test info["ApproximateNumberOfMessages"] == "0"
    end

    @testset "Delete Queues" begin
        queue_name = "ocaws-jl-test-queue-" * lowercase(Dates.format(now(Dates.UTC), "yyyymmddTHHMMSSZ"))
        queue = create_queue(queue_name=queue_name)
        sqs_delete_queue(queue)

        deleted_queue = sqs_get_queue(aws, queue_name)
        @test deleted_queue == nothing
    end

    cleanup_queues()
end