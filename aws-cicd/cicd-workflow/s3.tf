################### S3 ######################
# create s3 bucket to keep the logs/build artifacts

resource "aws_s3_bucket" "meta-store" {
  bucket = "codebuild-metastore"
}

# add bucket access control

# resource "aws_s3_bucket_acl" "meta-store-acl" {
#   bucket = aws_s3_bucket.meta-store.id
#   acl    = "private"
# }
