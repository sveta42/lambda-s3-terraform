exports.handler = async (event) => {

    const responseBody = {
        "key3": "value3",
        "key2": "value2",
        "key1": "value1"
    };

    const response = {
        "statusCode": 200,
        "headers": {
            "my_header": "my_value"
        },
        "body": JSON.stringify(responseBody),
        "isBase64Encoded": false
    };

    return response;
};