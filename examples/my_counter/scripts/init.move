script{
use {{sender}}::MyCounter;

fun main(account: signer) {
    MyCounter::init(&account);
}
}
