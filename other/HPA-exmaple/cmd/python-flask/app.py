from flask import Flask, escape, request
import random
import string

def randomString(stringLength=10):
    """Generate a random string of fixed length """
    letters = string.ascii_lowercase
    return ''.join(random.choice(letters) for i in range(stringLength))


app = Flask(__name__)
RANDOMSTR = randomString(16)

@app.route('/')
def hello():
    return f'Hello, FROM {RANDOMSTR}!'

if __name__ == '__main__':
    # app.run(host, port, debug, options)
    # 默认值：host=127.0.0.1, port=5000, debug=false
    app.run(host="0.0.0.0",port=80,debug=True)