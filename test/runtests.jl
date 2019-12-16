#==============================================================================#
# SQS/test/runtests.jl
#
# Copyright OC Technology Pty Ltd 2014 - All rights reserved
#==============================================================================#


using AWSSQS
using AWSCore
using Test
using Dates

AWSCore.set_debug_level(1)
aws = AWSCore.aws_config(region="ap-southeast-2")

@testset "AWSSQS.jl" begin
    include("queue.jl")
end
