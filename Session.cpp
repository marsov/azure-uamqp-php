#include "Session.h"
#include "azure_uamqp_c/uamqp.h"
#include "Connection.h"

Session::Session(Connection *connection)
{
    this->connection = connection;
    session = NULL;
    closeRequested = false;

    session = session_create(connection->getConnectionHandler(), NULL, NULL);
    if (session == NULL) {
        throw Php::Exception("Could not create session");
    }
    session_set_incoming_window(session, 2147483647);
    session_set_outgoing_window(session, 65536);
}

SESSION_HANDLE Session::getSessionHandler()
{
    return session;
}

Connection* Session::getConnection()
{
    return connection;
}

void Session::close()
{
    if (closeRequested) {
        return;
    }

    closeRequested = true;

    if (session != NULL) {
        session_destroy(session);
        session = NULL;
    }

    connection = NULL;
}
