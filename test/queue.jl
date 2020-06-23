function cleanup_queues()
    for q in sqs_list_queues(aws, "ocaws-jl-test-queue-")
        sqs_delete_queue(q)
    end
end

@testset "FIFO Queue" begin
    create_fifo_queue(; queue_name="ocaws-jl-test-queue-" * lowercase(Dates.format(now(Dates.UTC), "yyyymmddTHHMMSSZ")) * ".fifo") = sqs_create_queue(aws, queue_name; Dict(:FifoQueue => "true")...)

    @testset "Create FIFO Queue" begin
        queue_name = "ocaws-jl-test-queue-" * lowercase(Dates.format(now(Dates.UTC), "yyyymmddTHHMMSSZ")) * ".fifo"
        created_queue = create_fifo_queue(queue_name=queue_name)
        fetched_queue = sqs_get_queue(aws, queue_name)

        @test created_queue[:resource] == fetched_queue[:resource]
    end

    @testset "Send Message" begin
        queue = create_fifo_queue()

        options = Dict(
            :MessageGroupId => "1aaa11aa-11aa-11a1-aa1a-111aa1a1a111",
            :MessageDeduplicationId => "1aaa11aa-11aa-11a1-aa1a-111aa1a1a111"
        )
        sqs_send_message(queue, "Hello!", options...)
        message = sqs_receive_message(queue)

        @test haskey(message, :id) && !isempty(message[:id])
        @test message[:message] == "Hello!"
    end

    @testset "Queue Attributes" begin
        queue = create_fifo_queue()
        info = sqs_get_queue_attributes(queue)

        @test info["FifoQueue"] == "true"
    end
end

@testset "Queue" begin
    create_queue(; queue_name="ocaws-jl-test-queue-" * lowercase(Dates.format(now(Dates.UTC), "yyyymmddTHHMMSSZ"))) = sqs_create_queue(aws, queue_name)

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

        @test haskey(message, :id) && !isempty(message[:id])
        @test message[:message] == "Hello!"
    end

    @testset "Send Batch Messages" begin
        queue = create_queue()
        num_messages = 10

        msgs = repeat(["test message"], outer=num_messages)
        sqs_send_message_batch(queue, msgs)

        message_count = sqs_count(queue)
        @test message_count == num_messages

        while (m=sqs_receive_message(queue)) != nothing
            @test haskey(m, :id) && !isempty(m[:id])
            @test m[:message] == "test message"
        end
    end

    @testset "Queue Attributes" begin
        queue = create_queue()
        info = sqs_get_queue_attributes(queue)

        @test info["ApproximateNumberOfMessages"] == "0"
    end

    @testset "Delete Queue" begin
        queue_name = "ocaws-jl-test-queue-" * lowercase(Dates.format(now(Dates.UTC), "yyyymmddTHHMMSSZ"))
        queue = create_queue(queue_name=queue_name)
        sqs_delete_queue(queue)
        deleted_queue = sqs_get_queue(aws, queue_name)

        @test deleted_queue == nothing
    end

@testset "Message Visibility" begin
        queue = create_queue()
        message = "Hello!"

        @testset "Default" begin
            sqs_send_message(queue, message)
            response = sqs_receive_message(queue)

            @test response[:message] == message

            response = sqs_receive_message(queue)

            @test response == nothing
        end

        @testset "0 seconds" begin
            sqs_send_message(queue, message)
            response = sqs_receive_message(queue)

            @test response[:message] == message

            sqs_change_message_visibility(queue, response, 0)
            response = sqs_receive_message(queue)

            @test response[:message] == message
        end

        @testset "3 seconds" begin
            sqs_send_message(queue, message)
            response = sqs_receive_message(queue)

            @test response[:message] == message

            sqs_change_message_visibility(queue, response, 3)
            response = sqs_receive_message(queue)

            @test response == nothing
            
            sleep(3)
            response = sqs_receive_message(queue)

            @test response[:message] == message
        end
    end
end

cleanup_queues()
