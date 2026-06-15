#ifndef UAMQP_PHP_SESSION_H
#define UAMQP_PHP_SESSION_H
#include <phpcpp.h>
#include "Connection.h"

class Connection;

class Session
{
private:
    SESSION_HANDLE session = NULL;
    Connection *connection = NULL;
    bool closeRequested = false;

public:
    Session(Connection *connection);
    virtual ~Session() = default;

    SESSION_HANDLE getSessionHandler();
    Connection* getConnection();
    void close();
};

#endif
