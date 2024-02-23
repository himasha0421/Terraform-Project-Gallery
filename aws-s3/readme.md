### bucket policy


{
    "Version": "2012-10-17",
    "Id": "webhosting-policy",
    "Statement": [
        {
            "Sid": "deny-public-access",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::web-hosting-hj",
                "arn:aws:s3:::web-hosting-hj/*"
            ],
            "Condition": {
                "StringNotEquals": {
                    "aws:PrincipalArn": "arn:aws:iam::630210676530:root"
                }
            }
        }
    ]
}

### static webhosting 

{
    "Version": "2012-10-17",
    "Id": "webhosting-policy",
    "Statement": [
        {
            "Sid": "allow-public-access",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": [
                "arn:aws:s3:::web-hosting-hj",
                "arn:aws:s3:::web-hosting-hj/*"
            ]
        }
    ]
}

### policy generator

https://awspolicygen.s3.amazonaws.com/policygen.html
