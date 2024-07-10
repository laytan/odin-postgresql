package pq

import "core:c/libc"

LIB :: #config(POSTGRES_LIB, "system:pq")

foreign import pq { LIB }

// An opaque handle to a connection. 
Conn :: distinct rawptr

// An opaque handle to a result.
//
// The result structure encapsulates the result returned by the server. libpq application
// programmers should be careful to maintain the result abstraction. Use the accessor functions
// to get at the contents. Avoid directly referencing the fields because they are subject to change.
Result :: distinct rawptr

// An opaque handle to a cancel object.
Cancel :: distinct rawptr

OID :: distinct u32
INVALID_OID: OID: 0

Encoding :: distinct i32
ENCODING_ERROR: Encoding: -1

SSL_Key_Pass_Hook :: #type proc "c" (buf: [^]byte, size: i32, conn: Conn) -> i32

// Called when a notice is retrieved from the server or generated internally by libpq.
// It is passed a `Result` in the state of `Non_Fatal_Error`. (This allows the receiver to extract
// individual fields using `result_error_field`, or obtain a complete preformatted message using
// `result_error_message` or `result_verbose_error_message`.) The same user pointer passed to
// `set_notice_receiver` is passed.
//
// The default notice receiver extracts the message using `result_error_message` and passes it on
// to the notice processor.
Notice_Receiver :: #type proc "c" (user: rawptr, res: Result)

// Responsible for handling a notice or warning message given in text form. It is passed the string
// text of the message (including a trailing newline), plus a user pointer from `set_notice_processor`.
//
// The default notice processor prints to stderr.
Notice_Processor :: #type proc "c" (user: rawptr, message: cstring)

Event_Proc :: #type proc "c" (evt_id: Event_ID, evt_info: rawptr, pass_through: rawptr) -> b32

Polling_Status :: enum i32 {
	Failed,
	Reading,
	Writing,
	Ok,
}

Connection_Status :: enum i32 {
	Ok,
	Bad,

	// Below are only possible in nonblocking mode:

	// Waiting for connection to be made.
	Started,
	// Connection OK; waiting to send.
	Made,
	// Waiting for a response from the server.
	Awaiting_Response,
	// Received authentication; waiting for backend start-up to finish.
	Auth_OK,
	// Negotiating environment-driven parameter settings.
	Set_Env,
	// Negotiating SSL encryption.
	SSL_Startup,
	// Internal state; connect() needed.
	Needed,
	// Checking if connection is able to handle write transactions.
	Check_Writable,
	// Consuming any remaining response messages on connection.
	Consume,
	// Negotiating GSSAPI.
	GSS_Startup,
	// Checking target server properties.
	Check_Target,
	// Checking if server is in standby mode.
	Check_Standby,
}

Ping :: enum i32 {
	// The server is running and appears to be accepting connections.
	OK,
	// The server is running but is in a state that disallows connections (startup, shutdown, or crash recovery).
	Reject,
	// The server could not be contacted. This might indicate that the server is not running,
	// or that there is something wrong with the given connection parameters (for example, wrong port number),
	// or that there is a network connectivity problem (for example, a firewall blocking the connection request).
	No_Response,
	// No attempt was made to contact the server, because the supplied parameters were obviously incorrect or there
	// was some client-side problem (for example, out of memory).
	No_Attempt,
}

Transaction_Status :: enum i32 {
	Idle,
	// Command in progress.
	Active,
	// Idle, within transaction block.
	In_Trans,
	// Idle, within failed transaction.
	In_Error,
	// Cannot determine status.
	Unknown,
}

Pipeline_Status :: enum i32 {
	// The pipeline mode is off.
	Off,
	// The pipeline mode is on.
	On,
	// The pipeline mode is on but is currently in an error state.
	Aborted,
}

Exec_Status :: enum i32 {
	// The string sent to the server was empty.
	Empty_Query,
	// Successful completion of a command returning no data.
	Command_OK,
	// Successful completion of a command returning data (such as `SELECT` or `SHOW`).
	Tuples_OK,
	// Copy Out (from server) data transfer started.
	Copy_Out,
	// Copy In (to server) data transfer started.
	Copy_In,
	// The server's response was not understood.
	Bad_Response,
	// A nonfatal error (a notice or warning) occurred.
	//
	// A result of `Non_Fatal_Error` will never be returned directly by `exec` or other query execution functions;
	// results of this kind are instead passed to the notice processor.
	Non_Fatal_Error,
	// A fatal error occurred.
	Fatal_Error,
	// Copy in/out (to and from server) data transfer started. This is currently only for streaming replication.
	Copy_Both,
	// The `Result` contains a single result tuple from the current command.
	// Only occurs in single row mode.
	Single_Tuple,
	// The `Result` represents a synchronization point in pipeline mode, requested by `pipeline_sync`.
	// This status occurs only when pipeline mode has been selected.
	Pipeline_Sync,
	// The `Result` represents a pipeline that has received an error from the server.
	// `get_result` must be called repeatedly, and each time it will return this status code until the end
	// of the current pipeline, at which point it will return `Pipeline_Sync` and normal processing can resume.
	Pipeline_Aborted,
}

Field_Code :: enum i32 {
	// The severity; the field contents are `ERROR`, `FATAL` or `PANIC` (in an error message), or
	// `WARNING`, `NOTICE`, `DEBUG`, `INFO`, or `LOG` (in a notice message), or a localized translation
	// of one of these. Always present.
	Severity = 'S',
	// Severity, without localization.
	Severity_Non_Localized = 'V',
	// The code identifies the type of error that has occurred; it can be used by front-end applications
	// to perform specific operations (such as error handling) in response to a particular database error.
	// For a list of possible codes, see [[Appendix A; https://www.postgresql.org/docs/16/errcodes-appendix.html]].
	// This field is not localizable, and is always present.
	SQL_State = 'C',
	// The primary human-readable error message (typically one line). Always present.
	Message_Primary = 'M',
	// An optional secondary error message carrying more detail about the problem. Might run to multiple lines.
	Message_Detail = 'D',
	// An optional suggestion what to do about the problem. This is intended to differ from detail in that it offers advice
	// (potentially inappropriate) rather than hard facts. Might run to multiple lines.
	Message_Hint = 'H',
	// A string containing a decimal integer indicating an error cursor position as an index into the original statement string.
	// The first character has index 1, and positions are measured in characters, not bytes.
	Statement_Position = 'P',
	// This is defined the same as `Statement_Position` but it is used when the cursor position refers to an internally
	// generated command rather than the one submitted by the client. The `Internal_Query` field will always appear when this field appears.
	Internal_Position = 'p',
	// The text of failed internally-generated command. This could be, for example, a SQL query issued by a PL/pgSQL function.
	Internal_Query = 'q',
	// An indication of the context in which the error occurred. Presently this includes a call stack traceback of active
	// procedural language functions and internally-generated queries. The trace is one entry per line, most recent first.
	Context = 'W',
	Schema_Name = 's',
	Table_Name = 't',
	Column_Name = 'c',
	Data_Type_Name = 'd',
	Constraint_Name = 'n',
	// The file name of the source-code location where the error was reported.
	Source_File = 'F',
	// The line number of the source-code location where the error was reporte.
	Source_Line = 'L',
	// The name of the source-code function reporting the error.
	Source_Function = 'R',
}

Format :: enum i32 {
	Text   = 0,
	Binary = 1,
}

Flush_Result :: enum i32 {
	Failure     = -1,
	Success     = 0,
	Would_Block = 1,
}

Nonblocking_Result :: enum i32 {
	Failure = -1,
	Success = 0,
}

Put_Copy_Result :: enum i32 {
	// An error occurred, use `error_message` to retrieve details.
	Failure      = -1,
	// Not queued because of full buffers (this will only happen in nonblocking mode).
	Full_Buffers = 0,
	// Data was queued.
	Queued       = 1,
}

Get_Copy_Result :: enum i32 {
	// -2 is returned when an error occurred, consult `error_message` for the reason.
	Failure     = -2,
	// -1 is returned when the `COPY` is done, call `get_result` to obtain the final result.
	Done        = -1,
	// Zero is returned for in progress `COPY`'s when `async` is set to true.
	In_Progress = 0,

	// NOTE: Any other value is the amount of bytes that have been retrieved, to be cast to an int.
}

Set_Encoding_Result :: enum i32 {
	Failure = -1,
	Success = 0,
}

Verbosity :: enum i32 {
	// Severity, primary text, and position, normally on a single line.
	Terse,
	// Terse + detail, hint, or context, might span multiple lines.
	Default,
	// All available fields.
	Verbose,
	// Severity and SQL_State error code if one is available (if not, the output is like .Terse mode).
	SQL_State,
}

Context_Visibility :: enum i32 {
	// Context field is never in messages.
	Never,
	// Context field is only in error messages.
	Errors,
	// Context field is in all messages.
	Always,
}

Trace_Flag :: enum i32 {
	// Don't include the timestamp.
	Suppress_Timestamp,
	// Redact some fields, such as object OIDs so the output is more convenient for testing frameworks.
	Regress_Mode,
}

Trace_Flags :: bit_set[Trace_Flag; i32]

Result_Copy_Flag :: enum i32 {
	// Copy the source result's attributes (column definitions).
	Attrs,
	// Copy the source result's tuples (implies copying the attributes).
	Tuples,
	// Copy the source result's events. (But any instance data associated with the source is not copied.)
	Events,
	// Copy the source result's notify hooks.
	Notice_Hooks,
}

Result_Copy_Flags :: bit_set[Result_Copy_Flag; i32]

Res_Att_Desc :: struct {
	// Column name.
	name:      cstring,
	// Source table, if known.
	table_id:  OID,
	// Source column, if known,
	column_id: i32,
	// Format code for value.
	format:    Format,
	type_id:   OID,
	// Type size.
	type_len:  i32,
	// type-specific modifier info.
	atttypmod: i32,

}

Conninfo_Option :: struct {
	// The keyword of the option.
	keyword:   cstring,
	// Fallback environment variable name.
	env_var:   cstring,
	// Fallback compiled in default name.
	compiled:  cstring,
	// Option's current value, or nil.
	val:       cstring,
	// Label for field in connect dialog.
	label:     cstring,
	// Indicates how to display this field in a connect dialog. Values are:
	// ""	Display entered value as is
	// "*"	Password field - hide value
	// "D"	Debug option - don't show by default
	disp_char: cstring,
	// Field size in characters for dialog.
	disp_size: i32,
}

pqbool :: i8

Print_Opt :: struct {
	// Print output field headings and row count.
	header:      pqbool,
	// Fill align the fields.
	align:       pqbool,
	// Old brain dead format.
	standard:    pqbool,
	// Output HTML tables.
	html3:       pqbool,
	// Expand tables.
	expanded:    pqbool,
	// Use pager for output if needed.
	pager:       pqbool,
	// Field separator.
	field_sep:   cstring,
	// Attributes for HTML table element.
	table_opt:   cstring,
	// HTML table caption.
	caption:     cstring,
	// null-terminated array of replacement field names.
	field_names: [^]cstring,
}

Notify :: struct {
	// Notification channel name.
	relname: cstring,
	// Process ID of notifying server process.
	be_pid:  i32,
	// Notification payload string.
	extra:   cstring,
	// Private to libpq, do not use.
	_next:   ^Notify,
}

Event_ID :: enum i32 {
	// The register event occurs when `register_event_proc` is called. It is the ideal time to
	// initialize any `instance_data` an event procedure may need. Only one register event will
	// be fired per event handler connection. If the event procedure fails (returns 0), the registration is cancelled.
	// If the event procedure returns false the registration is aborted.
	// The `evt_info` should be cast to `Event_Register`.
	Register,
	// The connection reset event is fired on completion of `reset` or `reset_poll`. In both cases
	// the event is only fired if the reset was successful. The return value of the event procedure
	// is ignored in PostgreSQL 15 and later. With earlier versions, however, it's important to return
	// success or the connection will be aborted.
	// The `evt_info` should be cast to `Event_Conn_Reset`.
	Conn_Reset,
	// The connection destroy event is fired in response to `finish`. It is the event procedure's
	// responsibility to properly clean up its event data as libpq has no ability to manage this memory.
	// Failure to clean up will lead to memory leaks.
	// This event is fired before `finish` does any other cleanup. The return value is ignored.
	// The `evt_info` should be cast to `Event_Conn_Destroy`.
	Conn_Destroy,
	// The result creation event is fired in response to any query execution that generates a result,
	// including `get_result`. This event will only be fired after the result has been created successfully.
	// If the event procedure returns false, that event procedure will be ignore for the remaining lifetime of the result.
	// The `evt_info` should be cast to `Event_Result_Create`.
	Result_Create,
	// The result copy event is fired in response to `copy_result`. This event will only be fired after the copy is complete.
	// Only event procedures that have successfully handled the `Result_Create` or `Result_Copy` event for the
	// source result will receive `Result_Copy` events.
	// If the event procedure returns false, that event procedure will be ignored for the remaining lifetime of the new result.
	// The `evt_info` should be cast to `Event_Result_Copy`.
	Result_Copy,
	// The result destroy event is fired in response to `clear`. It is the event procedure's responsibility
	// to properly clean up its event data as libpq has no ability to manage this memory. Failure to clean up will lead to memory leaks.
	// The event is fired just before `clear` performs any other cleanup. The return value is ignored.
	Result_Destroy,
}

Event_Register :: struct {
	conn: Conn,
}

Event_Conn_Reset :: struct {
	conn: Conn,
}

Event_Conn_Destroy :: struct {
	conn: Conn,
}

Event_Result_Create :: struct {
	conn:   Conn,
	result: Result,
}

Event_Result_Copy :: struct {
	src:  Result,
	dest: Result,
}

Event_Result_Destroy :: struct {
	result: Result,
}

@(link_prefix="PQ")
foreign pq {
/*----- [[Database Connection Control Functions; https://www.postgresql.org/docs/16/libpq-connect.html]] -----*/

	// Makes a new connection to the database server.
	// 
	// This function opens a new database connection using the parameters taken from two nil-terminated arrays.
	// The first, `keywords`, is defined as an array of strings, each one being a key word.
	// The second, `values`, gives the value for each key word.
	//
	// When `expand_dbname` is `true`, the `dbname` key word value is allowed to be recognized as a `conninfo` string. See below for details.
	//
	// The passed arrays can be empty to use all default parameters, or can contain one or more parameter settings. They should be matched in length.
	// Processing will stop with the last non-nil element of the `keywords` array.
	//
	// [[More info; https://www.postgresql.org/docs/16/libpq-connect.html#LIBPQ-PQCONNECTDBPARAMS]]
	@(link_name="PQconnectdbParams")
	connectdb_params :: proc(keywords: [^]cstring, values: [^]cstring, expand_dbname: b32) -> Conn ---

	// Makes a new connection to the database server.
	//
	// This function opens a new database connection using the parameters taken from the string `conninfo`.
	//
	// The passed string can be empty to use all default parameters, or it can contain one or more parameter settings
	// separated by whitespace. Each parameter setting is in the form `keyword = value`. Spaces around the equal sign are optional.
	// To write an empty value, or a value containing spaces, surround it in single quotes, e.g., `keyword = 'a value`.
	// Single quotes and backslashes withing the value must be escaped with a backslash, i.e., `\'` and `\\`.
	connectdb :: proc(conninfo: cstring) -> Conn ---
	
	// Makes a new connection to the database server.
	//
	// This is the predecessor of `connectdb` with a fixed set of parameters. It has the same functionality except
	// that the missing parameters will always take on default values. write `nil` or an empty string for any one of the fixed
	// parameters that is to be defaulted.
	//
	// If the `dbName` contains an = sign, it is taken as a `conninfo` string in exactly the same way as if it had been
	// passed to `connectdb`, and the remaining parameters are then applied as above.
	@(link_name="PQsetdbLogin")
	setdb_login :: proc(
		host:    cstring = nil,
		port:    cstring = nil,
		options: cstring = nil,
		tty:     cstring = nil,
		dbname:  cstring = nil,
		login:   cstring = nil,
		pwd:     cstring = nil,
	) -> Conn ---
	
	// Makes a connection to the database server in a nonblocking manner.
	//
	// [[More info; https://www.postgresql.org/docs/16/libpq-connect.html#LIBPQ-PQCONNECTSTARTPARAMS]]
	@(link_name="PQconnectStartParams")
	connect_start_params :: proc(keywords: [^]cstring, values: [^]cstring, expand_dbname: b32) -> Conn ---

	// Makes a connection to the database server in a nonblocking manner.
	//
	// [[More info; https://www.postgresql.org/docs/16/libpq-connect.html#LIBPQ-PQCONNECTSTARTPARAMS]]
	@(link_name="PQconnectStart")
	connect_start :: proc(conninfo: cstring) -> Conn ---

	// Poll the connection status after one of the 2 functions above succeeds.
	//
	// [[More info; https://www.postgresql.org/docs/16/libpq-connect.html#LIBPQ-PQCONNECTSTARTPARAMS]]
	@(link_name="PQconnectPoll")
	connect_poll :: proc(conn: Conn) -> Polling_Status ---

	// Returns the default connection options.
	//
	// NOTE: After processing the options array, free it by passing it to `conninfoFree`. If that is not done,
	// a small amount of memory is leaked for each call to `conndefaults`.
	//
	// [[More info; https://www.postgresql.org/docs/16/libpq-connect.html#LIBPQ-PQCONNDEFAULTS]]
	@(link_name="PQconndefaults")
	conn_defaults  :: proc() -> [^]Conninfo_Option ---

	// Returns parsed connection options from the provided connection string.
	//
	// No defaults are inserted.
	//
	// If `errmsg` is not nil, then `errmsg^` is set to nil on success, else to an allocated error string
	// explaining the problem. (It is also possible for `errmsg^` to be nil and the result to be nil, this indicates out-of-memory.).
	//
	// NOTE: After processing the options array , free it by passing it to `conninfoFree`. If that is not done,
	// some memory is leaked for each callto `conninfoParse`. Conversely, if an error occurs and `errmsg` is not nil,
	// be sure to free the error string using `freemem`.
	//
	// [[More info; https://www.postgresql.org/docs/16/libpq-connect.html#LIBPQ-PQCONNINFOPARSE]]
	@(link_name="PQconninfoParse")
	conninfo_parse :: proc(conninfo: cstring, errmsg: ^cstring = nil) -> [^]Conninfo_Option ---
	
	// Closes the connection to the server. Also frees memory used by the `Conn` object.
	//
	// Note that even if the server connection attempt fails (as indicated by `status`), the application
	// should call `finish` to free the memory used by the `Conn` object. The `conn` pointer must not be used
	// again after `finish` has been called.
	finish :: proc(conn: Conn) ---
	
	// Resets the communication channel to the server.
	//
	// This function will close the connection to the server and attempt to reestablish a new connection to the same server,
	// using all the same parameters previously used. This might be useful for error recovery if a working connection is lost.
	reset :: proc(conn: Conn) ---
	
	// Resets the communication channel to the server, in a nonblocking manner.
	//
	// [[More info; https://www.postgresql.org/docs/16/libpq-connect.html#LIBPQ-PQRESETSTART]]
	@(link_name="PQresetStart")
	reset_start :: proc(conn: Conn) -> b32 ---

	// If `resetStart` returned true, poll the status using this function.
	@(link_name="PQresetPoll")
	reset_poll  :: proc(conn: Conn) -> Polling_Status ---
	
	// Reports the status of the server. It accepts connection parameters identical to those of `connectdbParams`, described above.
	// It is not, however, necessary to supply correct user name, password, or database name values to obtain the server status.
	@(link_name="PQpingParams")
	ping_params :: proc(keywords: [^]cstring, values: [^]cstring, expand_dbname: b32) -> Ping ---

	// Reports the status of the server. It accepts a connection parameter identical to those of `connectdb` described above.
	// It is not, however, necessary to supply correct user name, password, or database name value to obtain the server status.
	@(link_name="PQping")
	ping :: proc(conninfo: cstring) -> Ping ---
	
	// [[More info; https://www.postgresql.org/docs/16/libpq-connect.html#LIBPQ-PQSETSSLKEYPASSHOOK-OPENSSL]]
	@(link_name="PQsetSSLKeyPassHook_OpenSSL")
	set_ssl_key_pass_hook :: proc(hook: SSL_Key_Pass_Hook) ---
	
	// [[More info; https://www.postgresql.org/docs/16/libpq-connect.html#LIBPQ-PQGETSSLKEYPASSHOOK-OPENSSL]]
	@(link_name="PQgetSSLKeyPassHook_OpenSSL")
	ssl_key_pass_hook :: proc() -> SSL_Key_Pass_Hook ---


/*----- [[Connection State Functions; https://www.postgresql.org/docs/16/libpq-status.html]] -----*/

	// Returns the database name of the connection.
	db       :: proc(conn: Conn) -> cstring ---
	// Returns the user name of the connection.
	user     :: proc(conn: Conn) -> cstring ---
	// Returns the password of the connection.
	pass     :: proc(conn: Conn) -> cstring ---
	// Returns the host of the connection.
	host     :: proc(conn: Conn) -> cstring ---
	// Returns the server IP address of the active connection.
	// This can be the address that a host name resolved to, or an IP address provided through
	// the hostaddr parameter.
	hostaddr :: proc(conn: Conn) -> cstring ---
	// Returns the port of the connection.
	port     :: proc(conn: Conn) -> cstring ---
	// Returns the command-line options passed in the connection request.
	options  :: proc(conn: Conn) -> cstring ---

	// Returns the status of the connection.
	//
	// [[More Info; https://www.postgresql.org/docs/16/libpq-status.html#LIBPQ-PQSTATUS]]
	status  :: proc(conn: Conn) -> Connection_Status ---
	
	// Returns the current in-transaction status of the server.
	//
	// WARN: PQtransactionStatus will give incorrect results when using a PostgreSQL 7.3 server that has the parameter autocommit set to off. The server-side autocommit feature has been deprecated and does not exist in later server versions.
	@(link_name="PQtransactionStatus")
	transaction_status :: proc(conn: Conn) -> Transaction_Status ---
	
	// Looks up a current parameter setting of the server.
	//
	// [[More Info; https://www.postgresql.org/docs/16/libpq-status.html#LIBPQ-PQPARAMETERSTATUS]]
	@(link_name="PQparamterStatus")
	parameter_status :: proc(conn: Conn, param: cstring) -> cstring ---
	
	// Interrogates the frontend/backend protocol being used.
	//
	// [[More Info; https://www.postgresql.org/docs/16/libpq-status.html#LIBPQ-PQPROTOCOLVERSION]]
	@(link_name="PQprotocolVersion")
	protocol_version :: proc(conn: Conn) -> i32 ---

	// Returns an integer representing the backend version.
	//
	// [[More Info; https://www.postgresql.org/docs/16/libpq-status.html#LIBPQ-SERVERVERSION]]
	@(link_name="PQserverVersion")
	server_version :: proc(conn: Conn) -> i32 ---
	
	// Returns the error message most recently generated by an operation on the connection.
	//
	// The returned string does not need to be freed, note that the string is overwritten between
	// function calls so you can't keep it around after calling another function.
	@(link_name="PQerrorMessage")
	error_message :: proc(conn: Conn) -> cstring ---
	
	// Obtains the file descriptor number of the connection socket to the server.
	// A valid descriptor will be greater than or equal to 0; a result of -1 indicates that no
	// server connection is currently open. (This will not change during normal operation, but could change
	// during connection setup or reset.)
	socket :: proc(conn: Conn) -> i32 ---
	
	// Returns the process ID (PID) of the backend process handling this connection.
	//
	// The backend PID is useful for debugging purposes and for comparison to `NOTIFY` messages (which include the PID of the notifying backend process).
	// Note that the PID belongs to the process executing on the database server host, not the local host.
	@(link_name="PQbackendPID")
	backend_pid :: proc(conn: Conn) -> i32 ---
	
	// Returns true if the connection authentication method required a password, but none was available.
	@(link_name="PQconnectionNeedsPassword")
	connection_needs_password :: proc(conn: Conn) -> b32 ---
	
	@(link_name="PQconnectionUsedPassword")
	// Returns true if the connection authentication method used a password.
	connection_used_password :: proc(conn: Conn) -> b32 ---
	
	// Returns true if the connection authentication method used GSSAPI.
	@(link_name="PQconnectionUsedGSSAPI")
	connection_used_gssapi :: proc(conn: Conn) -> b32 ---

	// Returns true if the connection uses SSL.	
	@(link_name="PQsslInUse")
	ssl_in_use :: proc(conn: Conn) -> b32 ---
	
	// Returns SSL-related information about the connection.
	//
	// [[The list of available attributes; https://www.postgresql.org/docs/16/libpq-status.html#LIBPQ-PQSSLATTRIBUTE]]
	@(link_name="PQsslAttribute")
	ssl_attribute :: proc(conn: Conn, attribute_name: cstring) -> cstring ---
	
	// Returns an array of SSL attribute names that can be used in `ssl_attribute`.
	@(link_name="PQsslAttributeNames")
	ssl_attribute_names :: proc(conn: Conn) -> [^]cstring ---
	
	// Returns a pointer to an SSL-implementation-specific object describing the connection.
	//
	// The available names depend on the SSL implementation, for OpenSSL there is one struct available under
	// "OpenSSL".
	@(link_name="PQsslStruct")
	ssl_struct :: proc(conn: Conn, name: cstring) -> rawptr ---


/*----- [[Command Execution Functions; https://www.postgresql.org/docs/16/libpq-exec.html]] -----*/
	
	// Submits a command to the server and waits for the result.
	//
	// Returns a Result pointer or nil (when out of memory or inability to send to server).
	// The `result_status` function should be called to check the return value for any errors.
	// The `error_message` function can be used to get more information about the errors.
	//
	// The command string can include multiple SQL commands (seperated by semicolons).
	// Multiple queries sent in a single `exec` call are processed in a single transaction, unless there are
	// explicit `BEGIN/COMMIT` commands included in the query string to divide it into multiple transactions.
	// Note however that the returned `Result` struct describes only the result of the last command executed.
	// Should one of the commands fail, processing of the string stops with it and the returned `Result`
	// describes the error condition.
	exec :: proc(conn: Conn, command: cstring) -> Result ---

	// Submits a command to the server and waits for the result, with the ability to pass parameters separately from the SQL command text.
	//
	// `exec_params` is like `exec`, but offers additional functionality; parameter values can be specified separately from the command string proper,
	// and query results can be requested in either text or binary format. `exec_params` is supported only in protocol 3.0 and later connections;
	// It will fail when using protocol 2.0.
	//
	// The primary advantage over `exec` is that parameter values can be separated from the command string, thus avoiding
	// the need for tedious and error-prone quoting and escaping.
	//
	// NOTE: Unlike `exec` it allows at most one SQL command in the given string. (There can be semicolons in it,
	// but not more than one nonempty command.) This is a limitation of the underlying protocol, but has some usefulness
	// as an extra defense against SQL-injection attacks.
	//
	// INFO: Specifying parameter types via OIDs is tedious, particularly if you prefer not to hard-wire particular
	// OID values into your program. However, you can avoid doing so even in cases where the server by itself cannot
	// determine the type of the parameter, or chooses a different type than you want. In the SQL command text, attach an
	// explicit cast to the parameter symbol to show what data type you will send. For example:
	// `SELECT * FROM mytable WHERE x = $1::bigint;`
	// This forces the parameter `$1` to be treated as `bigint`, whereas by default it would be assigned the same type as
	// `x`. Forcing the parameter type decision, either this way or by specifying a numeric type OID, is strongly recommended when
	// sending parameters values in binary format, because binary format has less redundancy than text format and so there is
	// less chance that the server will detect a type mismatch mistake for you.
	//
	// Inputs:
	// - conn:         The connection object to send the command through.
	//
	// - command:       The SQL command string to be executed. If parameters are used, they are referred to in the comand string as `$1`, `$2`, etc.
	//
	// - n_params:      The number of parameters supplied; it is the length of the arrays `param_types`, `param_values`, `param_lengths`, and `param_formats`.
	//
	// - param_types:   Specifies, by OID, the data types to be assigned to the parameter symbols. If `param_types` is `nil`, or any particular element in the array is zero,
	//                  the server infers the data type for the parameter symbol in the same way it would do for an untyped literal string.
	//
	// - param_values:  Specifies the actual values of the parameters. A nil pointer in this array means the corresponding parameter is nil;
	//                  otherwise the pointer points to a zero-terminated text string (for text formats) or binary data in the format expected by the server (for binary format).
	//
	// - param_lengths: Specifies the actual data lengths of binary-format parameters. It is ignored for nil parameters and text-format parameters.
	//                  The array pointer can be nil when there are no binary parameters.
	//
	// - param_formats: Specifies whether parameters are text (put a zero in the array entry for the corresponding parameter) or binary (put a one in the array entry for the corresponding parameter).
	//                  If the array pointer is nil then all parameters are presumed to be text strings.
	//
	// - result_format: Specify zero to obtain results in text format, or one to obtain results in binary format.
	//                  (There is not currently a provision to obtain different result columns in different formats, although that is possible in the underlying protocol.)
	@(link_name="PQexecParams")
	exec_params :: proc(
		conn:          Conn,
		command:       cstring,
		n_params:      i32,
		param_types:   [^]OID,
		param_values:  [^][^]byte,
		param_lengths: [^]i32,
		param_formats: [^]Format,
		result_format: Format,
	) -> Result ---
	
	// Submits a request to create a prepared statement with the given parameters, and waits for completion.
	//
	// Creates a prepared statement for later execution with `exec_prepared`. This feature allows commands that will be used
	// repeatedly to be parsed and planned just once, rather than each time they are executed. This is supported only in protocol 3.0 and later;
	// it will fail when using protocol 2.0.
	//
	// The function creates a prepared statement named `stmt_name` from the query string, which must contain a single SQL command.
	// `stmt_name` can be `""` to create an unnamed statement, in which case any pre-existing unnamed statement is automatically replaced;
	// otherwise it is an error if the statement name is already defined in the current session. If any parameters are used, they are referred to in the
	// query as `$1`, `$2`, etc. `n_params` is the number of parameters for which types are pre-specified in `param_types`.
	// (The pointer can be nil when `n_params` is 0.) `param_types` specifies, by OID` the data types to be assigned to the parameter symbols.
	// If `param_types` is nil, or any particular element in the array is 0, the server assigns a data type to the parameter symbol
	// in the same way it would do for an untyped literal string. Also, the query can use parameter symbols with numbers higher than
	// `n_params`; data types will be inferred for these symbols as well. (See `describe_prepared` for a means to find out what data types were inferred.)
	//
	// As with `exec`, the result is nil when the request was not able to be sent at all. Use `error_message` for more info on errors.
	//
	// Prepared statements for use with `exec_prepared` can also be created by executing SQL PREPARE statements. Also, although there is no libpq function
	// for deleting a prepared statement, the SQL DEALLOCATE statement can be used for that purpose.
	prepare :: proc(conn: Conn, stmt_name: cstring, query: cstring, n_params: i32, param_types: [^]OID) -> Result ---
	
	// Sends a request to execute a prepared statement with given parameters and waits for the result.
	//
	// `exec_prepared` is like `exec_params`, but the command to be executed is specified by naming a previously-prepared statement,
	// instead of giving a query string. This feature allows commands that will be used repeatedly to be parsed and planned just once,
	// rather than each time they are executed. The statement must have been prepared previously in the current session.
	// This is supported in protocol 3.0 and later connections; it will fail when using protocol version 2.0.
	//
	// The parameters are identical to `exec_params`, except that the name of the prepared statement is given instead of a query string,
	// and the `param_types` parameter is not present (it is not needed since the prepared statement's parameter types were determined when it was created).
	@(link_name="PQexecPrepared")
	exec_prepared :: proc(
		conn:          Conn,
		stmt_name:     cstring,
		n_params:      i32,
		param_values:  [^][^]byte,
		param_lengths: [^]i32,
		param_formats: [^]Format,
		result_format: Format,
	) -> Result ---
	
	// Submits a request to obtain information about the specified prepared statement, and waits for completion.
	//
	// This allows an application to obtain information about a previously prepared statement. This is supported in protocol 3.0 and later;
	// it will fail when using protocol 2.0.
	//
	// `stmt_name` can be empty or nil to reference the unnamed statement, otherwise it must be the name of an existing prepared statement.
	// On success, result status OK will be returned. The functions `n_params` and `param_types` can be applied to this result to obtain info
	// about the parameters of the prepared statement, and the function `n_fields`, `f_name`, `f_type` etc provide info about the result columns.
	@(link_name="PQdescribePrepared")
	describe_prepared :: proc(conn: Conn, stmt_name: cstring) -> Result ---
	
	// Submits a request to obtain information about the specified portal, and waits for completion.
	//
	// This allows an application to obtain info about a previously created portal. (libpq does not provide any
	// direct access to portals, but you can use this function to inspect the properties of a cursor created with a
	// `DECLARE CURSOR` SQL statement. This is only supported in protocol 3.0 and later; it will fail when using protocol 2.0.
	//
	// `portal_name` can be empty or nil to reference the unnamed portal, otherwise it must be the name of an existing portal.
	// On success, result status OK will be returned. The functions `n_fields`, `f_name`, `f_type` etc can be applied to the result to
	// obtain info about the result columns.
	@(link_name="PQdescribePortal")
	describe_portal :: proc(conn: Conn, portal_name: cstring) -> Result ---
	
	// Returns the result status of the command.
	//
	// If the result status is `Tuples_OK`, then the functions described below can be used to retrieve
	// the rows returned by the query. Note that a `SELECT` command that happens to retrieve zero rows
	// still shows `Tuples_OK`, `Command_OK` is for commands that can never return rows (`INSERT`, `UPDATE`, etc.).
	// A response of `Empty_Query` might indicate a bug in the client software.
	//
	// A result of `Non_Fatal_Error` will never be returned directly by `exec` or other query execution functions;
	// results of this kind are instead passed to the notice processor.
	@(link_name="PQresultStatus")
	result_status :: proc(res: Result) -> Exec_Status ---
	
	// Converts the enumerated type returned by `result_status` into a string constant describing the status code.
	// The caller should not free the result.
	@(link_name="PQresStatus")
	res_status :: proc(status: Exec_Status) -> cstring ---
	
	// Returns the error message associated with the command, or an empty string if there was no error.
	//
	// If there was an error, the returned string will include a trailing newline. The caller should NOT free
	// the result directly. It will be freed when the associated `Result` handle is passed to `clear`.
	//
	// Immediately following `exec` or `get_result`, `error_message` (on the connection) will return the same
	// string as this function. However, a `Result` will retain its error message until destroyed, whereas the connection's error message
	// will change when subsequent operations are done. Use this function when you want to know the status associated with
	// a particular `Result`; use `error_message` when you want to know the status from the latest operation on the connection.
	@(link_name="PQresultErrorMessage")
	result_error_message :: proc(res: Result) -> cstring ---
	
	// Returns a reformatted error message associated with a `Result` object.
	//
	// NOTE: The caller must free the returned string.
	//
	// [[More info; https://www.postgresql.org/docs/16/libpq-exec.html#LIBPQ-PQRESULTVERBOSEERRORMESSAGE]]
	@(link_name="PQresultVerboseErrorMessage")
	result_verbose_error_message :: proc(res: Result) -> cstring ---
	
	// Returns an individual field of an error report.
	//
	// `field_code` is an error field identifier. nil is returned if the `Result` is not an errro or warning result, or
	// does not include the specified field. Field values will normally not include a trailing newline. The caller should not free the result.
	// It will be freed when the associated `Result` handle is passed to `clear`.
	@(link_name="PQresultErrorField")
	result_error_field :: proc(res: Result, field_code: Field_Code) -> cstring ---
	
	// Frees the storage associated with a `Result`. Every command result should be freed via `clear` when it is no longer needed.
	//
	// You can keep a `Result` object around for as long as you need it; it does not go away when you issue a new command,
	// nor even if you close the connection. To get rid of it, you must call `clear`. Failure to do this will result in memory leaks in your application.
	clear :: proc(res: Result) ---


/*----- [[Retrieving Query Result Information; https://www.postgresql.org/docs/16/libpq-exec.html#LIBPQ-EXEC-SELECT-INFO]] -----*/
	
	// Returns the number of rows (tuples) in the query result.
	// Because it returns an integer result, large result sets might overflow the return value.
	@(link_name="PQntuples")
	n_tuples :: proc(res: Result) -> i32 ---
	
	// Returns the number of columns (fields) in each row of the query result.
	@(link_name="PQnfields")
	n_fields :: proc(res: Result) -> i32 ---
	
	// Returns the column name associated with the given column number. Column numbers start at 0.
	// The caller should not free the result directly. It will be freed when the associated `Result` is
	// passed to `clear`.
	//
	// nil is returned if the column number is out of range.
	@(link_name="PQfname")
	f_name :: proc(res: Result, column_number: i32) -> cstring ---
	
	// Returns the column number associated with the given column name.
	//
	// -1 is returned if the given name does not match any column.
	//
	// The given name is treated like an identifier in an SQL command, it is downcased unless
	// double-qouted.
	@(link_name="PQfnumber")
	f_number :: proc(res: Result, column_name: cstring) -> i32 ---
	
	// Returns an OID of the table from which the given column was fetched. Column numbers start at 0.
	//
	// `INVALID_OID` is returned if the column number is out of range, or if the specified column is
	// not a simple reference to a table column, or when using pre-3.0 protocol. You can query the system
	// table `pg_class` to determine exactly which table is referenced.
	@(link_name="PQftable")
	f_table :: proc(res: Result, column_number: i32) -> OID ---
	
	// Returns the column number (within its table) of the column making up the specified query result column.
	// Query-result column numbers start at 0, but table columns have nonzero numbers.
	//
	// Zero is returned if the column number is out of range, or if the specified column is not a simple reference to a
	// table column, or when using pre-3.0 protocol.
	@(link_name="PQftablecol")
	f_tablecol :: proc(res: Result, column_number: i32) -> i32 ---

	// Returns the format code indicating the format of the given column. Column numbers start at 0.
	@(link_name="PQfformat")
	f_format :: proc(res: Result, column_number: i32) -> Format ---
	
	// Returns the data type associated with the given column number. The integer returned is the internal OID number of the type.
	// Column numbers start at 0.
	//
	// You can query the system table `pg_type` to obtain the names and properties of the various data types.
	// The OIDs of the built-in data types are defined in the `src/include/catalog/pg_type.h` header.
	@(link_name="PQftype")
	f_type :: proc(res: Result, column_number: i32) -> OID ---
	
	// Returns the type modifier of the column associated with the given column number. Column numbers start at 0.
	//
	// The interpretation of modifier values is type-specific; they typically indicate precision or size limits.
	// The value -1 is used to indicate "no information available". Most data types do not use modifiers, in which case
	// the value is always -1.
	@(link_name="PQfmod")
	f_mod :: proc(res: Result, column_number: i32) -> i32 ---
	
	// Returns the size in bytes of the column associated with the given column number. Column numbers start at 0.
	//
	// This returns the space allocated for this column in a database row, in other words the size of the server's internal representation
	// of the data type. (Accordingly, it is not really very useful to clients.) A negative value indicates the data type is variable-length.
	@(link_name="PQfsize")
	f_size :: proc(res: Result, column_number: i32) -> i32 ---
	
	// Returns a single field value of one row of a `Result`. Row and column numbers start at 0.
	// The caller should not free the result directly. It will be freed when the associated `Result` handle is passed to `clear`.
	//
	// For data in text format, the value returned is a null-terminated character string representation of the field value.
	// For data in binary format, the value is in the binary representation determined by the data type's `typsend` and `typreceive` functions.
	// (The value is actually followed by a zero byte in this case too, but that is not ordinarily useful, since the value is likely to contain embedded nulls.)
	//
	// An empty string is returned if the field value is nil, See `get_is_null` to distinguish null values from empty-string values.
	//
	// The pointer returned by `get_value` points to storage that is part of the `Result` structure. One should not modify the data it points
	// to, and one must explicitly copy the data into other storage if it is to be used past the lifetime of the `Result` itself.
	@(link_name="PQgetvalue")
	get_value :: proc(res: Result, row_number: i32, column_number: i32) -> [^]byte ---
	
	// Tests the field for a null value. Row and column numbers start at 0.
	@(link_name="PQgetisnull")
	get_is_null :: proc(res: Result, row_number: i32, column_number: i32) -> b32 ---
	
	// Returns the actual length of the field value in bytes. Row and column numbers start at 0.
	//
	// This is the actual data length for the particular data value, the size of the objects pointed to
	// by `get_value`. For text data format this is the same as `strlen()`. For binary format this is essential
	// information. Note that one should not rely on `f_size` to obtain the actual data length.
	@(link_name="PQgetlength")
	get_length :: proc(res: Result, row_number: i32, column_number: i32) -> i32 ---
	
	// Returns the number of parameters of a prepared statement.
	@(link_name="PQnparams")
	n_params :: proc(res: Result) -> i32 ---
	
	// Returns the data type of the indicated statement parameter. Parameter numbers start at 0.
	@(link_name="PQparamtype")
	param_type :: proc(res: Result, param_number: i32) -> OID ---

	// Prints out all the rows and, optionally, the column names to the specified output stream.
	//
	// NOTE: All data is assumed to be in text format.
	print :: proc(fout: ^libc.FILE, res: Result, po: ^Print_Opt) ---


/*----- [[Retrieving Other Result Information; https://www.postgresql.org/docs/16/libpq-exec.html#LIBPQ-EXEC-NONSELECT]] -----*/
	
	// Returns the command status tag from the SQL command that generated the `Result`.
	//
	// Commonly this is just the name of the command, but it might include additional data such as the number of rows processed.
	// The caller should not free the results directly. It will be freed when the associated `Result` handle is passed to `clear`.
	@(link_name="PQcmdStatus")
	cmd_status :: proc(res: Result) -> cstring ---
	
	// Returns the number of rows affected by the SQL command.
	//
	// This function returns a string containing the number of rows affected by the SQL statement that generated the `Result`.
	// This function can only be used following the execution of a `SELECT`, `CREATE TABLE AS`, `INSERT`, `UPDATE`,
	// `DELETE`, `MOVE`, `FETCH` or `COPY` statement, or an `EXECUTE` of a prepared query that contains an `INSERT`, `UPDATE` or `DELETE` statement.
	// If the command that generated the `Result` was anything else, an empty string is returned.
	//
	// The caller should not free the return value directly. It will be freed when the associated `Result` handle is passed to `clear`.
	@(link_name="PQcmdTuples")
	cmd_tuples :: proc(res: Result) -> cstring ---
	
	// Returns the OID of the inserted row, if the SQL command was an `INSERT` that inserted exactly one row into a table
	// that has OIDs, or a `EXECUTE` of a prepared query containing a suitable `INSERT` statement. Otherwise, this function returns `INVALID_OID`.
	// This function will also return `INVALID_OID` if the table affected by the `INSERT` statement does not contain OIDs.
	@(link_name="PQoidValue")
	oid_value :: proc(res: Result) -> OID ---


/*----- [[Escaping Strings for Inclusion in SQL Commands; https://www.postgresql.org/docs/16/libpq-exec.html#LIBPQ-EXEC-ESCAPE-STRING]] -----*/
	
	// Escapes a string for use within an SQL command. This is useful when inserting data values as literal constants in SQL commands.
	// Certain characters (such as qoutes or backslashes) must be escaped to prevent them from being interpreted specially by the SQL parser.
	//
	// This function allocates and the result should be freed with `free_mem`.
	// 
	// A terminating zero byte is not required and should not be counted in the length parameter.
	//
	// The return value has special characters escaped and contains a zero byte.
	// The single quotes that must surround PostgreSQL string literals are included in the result string.
	//
	// On error, this returns nil and the `Conn` will have an error set.
	//
	// Note that it is not necessary nor correct to do escaping when a data value is passed as a separate parameter in `exec_params` or its sibling routines.
	@(link_name="PQescapeLiteral")
	escape_literal :: proc(conn: Conn, str: cstring, length: uint) -> cstring ---
	
	// Escapes a string for use as an SQL identifier, such as a table, column, or function name.
	// This is useful when a user-supplied identifier might contain special characters that would otherwise not be interpreted as part of the identifier
	// by the SQL parser, or when the identifier might contain upper case characters whose case should be preserved.
	//
	// This function allocates and the result should be freed with `free_mem`.
	// 
	// A terminating zero byte is not required and should not be counted in the length parameter.
	//
	// The return value has special characters escaped and contains a zero byte.
	// The string will also be surrounded by double quotes.
	//
	// On error, this returns nil and the `Conn` will have an error set.
	@(link_name="PQescapeIdentifier")
	escape_identifier :: proc(conn: Conn, str: cstring, length: uint) -> cstring ---

	// Escapes string literals, much like `escape_literal` but the caller is responsible for providing
	// an appropriately sized buffer. Furthermore, it does not surround the string with single quotes.
	//
	// A terminating zero byte is not required and should not be counted in the length parameter.
	//
	// The returned value is the amount of bytes (excluding zero byte) written into `to`.
	//
	// If the `err` parameter is not nil it is used to indicate error condition, `true` means an error occurred.
	// A suitable message is stored in the `Conn` object.
	//
	// NOTE: the length of `to` must be at least `1+length*2` or the operation is undefined behavior.
	@(link_name="PQescapeStringConn")
	escape_string :: proc(conn: Conn, to: cstring, from: cstring, length: uint, err: ^b32) -> uint ---
	
	// Escapes binary data for use within an SQL command with the type bytea.
	// As with `escape_string_conn` this is only used when inserting data directly into an SQL command string.
	//
	// Special characters are either escaped using hex or backslash escaping, see Section 8.4 for more info.
	//
	// A terminating zero byte is not required and should not be counted in the length parameter.
	//
	// The `to_length` point to a variable that will hold the resultant escaped length (including zero byte).
	// 
	// This function allocates and the result should be freed with `free_mem`.
	//
	// The string will NOT automatically be surrounded by single quotes.
	// 
	// On error, this returns nil and the `Conn` will have an error set.
	@(link_name="PQescapeByteaConn")
	escape_bytea :: proc(conn: Conn, from: [^]byte, from_length: uint, to_length: ^uint) -> cstring ---
	
	// Converts a string/escaped version of bytea data into binary data -- the reverse of `escape_bytea_conn`.
	// This is needed when retrieving bytea data in text format, but not when retrieving it in binary format.
	//
	// This function allocates and the result should be freed with `free_mem`.
	//
	// This conversion is not exactly the inverse of `escape_bytea_conn`, because the string is not expected to be "escaped" when received
	// from `get_value`. In particular this means there is no need for string quoting considerations, and so no need for `Conn` parameter.
	@(link_name="PQunescapeBytea")
	unescape_bytea :: proc(from: cstring, to_length: ^uint) -> [^]byte ---


/*----- [[Asynchronous Command Processing; https://www.postgresql.org/docs/16/libpq-async.html]] -----*/

	// A typical application using these function will have a main loop that uses `select` or `poll` to wait for all
	// the conditions that it must respond to. One of the conditions will be input available from the server, which
	// in terms of `select` means readable data on the file descriptor indentified by `socket`. When the main loop detects
	// input ready, it should call `consume_input` to read the input. It can then call `is_busy`, followed by `get_result`
	// if `is_busy` returns false.
	// It can also call `notifies` to detect `NOTIFY` messages (See Section 31.7).
	//
	// A client that uses `send_query` and `get_result` can also attempt to cancel a command that is still being processed
	// by the server; See Section 31.5. But regardless of the return value of `cancel`, the application must continue with the normal
	// result-reading sequence using `get_result`. A successful cancellation will simply cause the command to terminate sooner than
	// it would have otherwise.
	//
	// By using the functions described in this section, it is possible to avoid blocking while waiting for input from the database server.
	// However, it is still possible that the application will block waiting to send output to the server. This is relatively uncommon but
	// can happen if very long SQL commands or data values are sent. (It is much more probably if the application sends data via `COPY IN`, however.)
	// To prevent this possibility and achieve completely nonblocking database operation, `set_nonblocking`, `is_nonblocking` and `flush` can be used.
	// After sending any command or data on a nonblocking connection, call `flush`. If it returns true, wait for the socket to become read- or write-ready.
	// If it becomes write-ready, call `flush` again. If it becomes read-ready, call `consume_input`, then call `flush` again.
	// Repeat until `flush` returns false. (It is necessary to check for read-ready and drain the input with `consume_input`, because
	// the server can block trying to send us data, e.g. NOTICE messaes, and won't read our data until we read its.)
	// Once `flush` returns false, wait for the socket to be read-ready and then read the response as described above.

	
	// Submits a command to the server without waiting for the results.
	// If false is returned (error), use `error_message` for more information about the failure.
	//
	// After a successful call, call `get_result` one or more times to obtain results.
	// `send_query` can not be called again on this connection until `get_result` has returned nil (indicating done).
	@(link_name="PQsendQuery")
	send_query :: proc(conn: Conn, command: cstring) -> b32 ---
	
	// Submits a command and separate parameters to the server without waiting for the results.
	//
	// This is equivalent to `send_query` except that query parameters can be specified separately from the query string.
	// This function's parameters are handled identically to `exec_params`.
	@(link_name="PQsendQueryParams")
	send_query_params :: proc(
		conn:          Conn,
		command:       cstring,
		n_params:      i32,
		param_types:   [^]OID,
		param_values:  [^][^]byte,
		param_lengths: [^]i32,
		param_formats: [^]Format,
		result_format: Format,
	) -> b32 ---
	
	// Sends a request to create a prepared statement with the given parameters, without waiting for completion.
	//
	// This is an asynchronous version of `prepare` and parameters are handled identically.
	//
	// After a successful call, call `get_result` one or more times to determine whether the server successfully created the prepared statement.
	@(link_name="PQsendPrepare")
	send_prepare :: proc(conn: Conn, stmt_name: cstring, query: cstring, n_params: i32, param_types: [^]OID) -> b32 ---

	// Submits a request to execute a prepared statement with the given parameters, without waiting for the results.
	//
	// This is similar to `send_query_params`, but the command to be executed is specified by naming a previously-prepared statement,
	// instead of giving a query string. The function's parameters are handled identically to `exec_prepared`.
	@(link_name="PQsendQueryPrepared")
	send_query_prepared :: proc(
		conn:          Conn,
		stmt_name:     cstring,
		n_params:      i32,
		param_values:  [^][^]byte,
		param_lengths: [^]i32,
		param_formats: [^]Format,
		result_format: Format,
	) -> b32 ---

	// Submits a request to obtain information about the specified prepared statement, without waiting for completion.
	//
	// This is an asynchronous version of `describe_prepared`.
	//
	// After a successful call, call `get_result` one or more times to determine whether the server successfully created the prepared statement.
	@(link_name="PQsendDescribePrepared")
	send_describe_prepared :: proc(conn: Conn, stmt_name: cstring) -> b32 ---

	// Submits a request to obtain information about the specified portal, without waiting for completion.
	//
	// This is an asynchronous version of `describe_portal`.
	//
	// After a successful call, call `get_result` one or more times to determine whether the server successfully created the prepared statement.
	@(link_name="PQsendDescribePortal")
	send_describe_portal :: proc(conn: Conn, portal_name: cstring) -> b32 ---
	
	// Waits for the next result from a prior asynchronous call and returns it.
	// A nil pointer is returned when the command is complete and there will be no more results.
	//
	// This must be called repeatedly until it returns a nil pointer, indicating that the command is done.
	// Each non-nil result from this should be processed using the same `Result` procedures previously described.
	// Don't forget to free each result with `clear` when done with it.
	//
	// Note that this will block only if a command is active and the necessary response data has not yet been ready to read by `consume_input`.
	//
	// NOTE: even when `result_status` indicates a fatal error, `get_result` should be called until it returns a nil pointer to allow
	// libpq to process the error information completely.
	//
	// Using `send_query` and `get_result` solves one of `exec`'s problems; if a command string contains multiple SQL commands,
	// the results of those commands can be obtained individually.
	//
	// In pipeline mode, this will return normally unless an error occurs; for any subsequent query sent after
	// the one that caused the error until (and excluding) the next synchronization point, a special result of type `Pipeline_Aborted`
	// will be returned, and a null pointer will be returned after it.
	// When the pipeline synchronization point is reached, a result of type `Pipeline_Sync` will be returned.
	// The result of the next query after the synchronization point follows immediately (that is, no null pointer is returned after the synchronization point.)
	@(link_name="PQgetResult")
	get_result :: proc(conn: Conn) -> Result ---
	
	// If input is available from the server, consume it.
	//
	// This normally returns true, indicating "no error", but returns false if there was some kind of trouble
	// (in which case `error_message` can be consulted).
	//
	// Note that the result does not say whether any input data was actually collected. After calling this,
	// the application can check `is_busy` and/or `notifies` to see if their state has changed.
	//
	// This can be called even if the application is not prepared to deal with the result or notification just yet.
	// The function will read available data and save it in a buffer, thereby causing a `select` read-ready indication to go away.
	//
	// The application can thus use `consume_input` to clear the `select` condition immediately, and then examine the results at leisure.
	@(link_name="PQconsumeInput")
	consume_input :: proc(conn: Conn) -> b32 ---
	
	// Returns true if a command is busy, that is, `get_result` would block waiting for input.
	// If false is returned `get_result` can be safely called without blocking.
	//
	// This will not itself attempt to read data from the server; therefore `consume_input` must be invoked first,
	// or the busy state will never end.
	@(link_name="PQisBusy")
	is_busy :: proc(conn: Conn) -> b32 ---
	
	// Sets the nonblocking status of the connection.
	//
	// Returns 0 if OK, -1 if error.
	//
	// NOTE: `exec` does not honor nonblocking mode.
	@(link_name="PQsetnonblocking")
	set_nonblocking :: proc(conn: Conn, arg: b32) -> Nonblocking_Result ---
	
	@(link_name="PQisnonblocking")
	is_nonblocking :: proc(conn: Conn) -> b32 ---
	
	// Attempts to flush any queued output data to the server.
	flush :: proc(conn: Conn) -> Flush_Result ---


/*----- [[Pipeline Mode; https://www.postgresql.org/docs/16/libpq-pipeline-mode.html]] -----*/
	
	// Returns the current pipeline mode status of the connection.
	@(link_name="PQpipelineStatus")
	pipeline_status :: proc(conn: Conn) -> Pipeline_Status ---
	
	// Causes a connection to enter pipeline mode.
	// Returns false if the connection is not idle, or is waiting for input.
	// This does not actually send anything to the server.
	@(link_name="PQenterPipelineMode")
	enter_pipeline_mode :: proc(conn: Conn) -> b32 ---
	
	// Causes a connection to exit pipeline mode if it is currently in pipeline mode and
	// has an empty queue and no pending results.
	// Returns false if above is not true or if there is an error on the pipeline that first
	// needs clearing.
	@(link_name="PQexitPipelineMode")
	exit_pipeline_mode :: proc(conn: Conn) -> b32 ---
	
	// Makes a sync point in the pipeline by sending a sync message and flushing.
	// This serves as a delimiter of an implicit transaction and an error recovery point.
	@(link_name="PQpipelineSync")
	pipeline_sync :: proc(conn: Conn) -> b32 ---
	
	// Sends a request for the server to flush the output buffer.
	//
	// The server flushes its output buffer automatically as a result of `pipeline_sync` being called,
	// or on any request when not in pipeline mode;
	// this function is useful to cause the server to flush its output buffer in pipeline mode
	// without establishing a synchronization point.
	// Note that the request is not itself flushed to the server automatically; use `flush` if necessary.
	@(link_name="PQsendFlushRequest")
	send_flush_request :: proc(conn: Conn) -> b32 ---


/*----- [[Retrieving Query Results Row-by-Row; https://www.postgresql.org/docs/16/libpq-single-row-mode.html]] -----*/

	// Ordinarily, libpq collects an SQL command's entire result and returns it to the application as a
	// single result. This can be unworkable for commands that return a large number of rows.
	// For such cases, applications can use `send_query` and `get_result` in single-row mode.
	// In this mode, the result row(s) are returned to the application one at a time,
	// as they are received from the server.
	
	// Select single-row mode for the currently executing query.
	//
	// This function can only be called immediately after `send_query` or one of its sibling functions,
	// before any other operation on the connection such as `consume_input` or `get_result`.
	// If called at the correct time, the function activates single-row mode for the current query and returns 1.
	// Otherwise the mode stays unchanged and the function returns 0.
	// In any case, the mode reverts to normal after completion of the current query.
	@(link_name="PQsetSingleRowMode")
	set_single_row_mode :: proc(conn: Conn) -> b32 ---


/*----- [[Cancelling Queries in Progress; https://www.postgresql.org/docs/16/libpq-cancel.html]] -----*/
	
	// Creates a data structure containing the information needed to cancel a command issued through
	// a particular db connection.
	//
	// Caller must free with `free_cancel`.
	@(link_name="PQgetCancel")
	get_cancel :: proc(conn: Conn) -> Cancel ---
	
	// Frees the data structure created by `get_cancel`.
	@(link_name="PQfreeCancel")
	free_cancel :: proc(cancel: Cancel) ---
	
	// Requests that the server abandon processing of the current command.
	//
	// If false is returned `errbuf` is filled with an explanatory error message.
	// `errbuf` must be a char array of size `errbuf_size`(the recommended size is 256 bytes).
	cancel :: proc(cancel: Cancel, errbuf: [^]byte, errbuf_size: i32) -> b32 ---


/*----- [[Asynchronous Notification; https://www.postgresql.org/docs/16/libpq-notify.html]] -----*/
	
	// Returns the next notification from a list of unhandled notification messages received from
	// the server.
	notifies :: proc(conn: Conn) -> ^Notify ---


/*----- [[Functions Associated with the `COPY` Command; https://www.postgresql.org/docs/16/libpq-copy.html]] -----*/
	
	// Sends data to the server during `COPY_IN` state.
	@(link_name="PQputCopyData")
	put_copy_data :: proc(conn: Conn, buf: [^]byte, n_bytes: i32) -> Put_Copy_Result ---

	// Sends end-of-data indication to the server during `COPY_IN` state.
	//
	// Ends the `COPY_IN` operation if `errormsg` is nil. If it is not nil then the `COPY` is forced
	// to fail with the given `errormsg` as the reason.
	//
	// Returns .Queued if the termination message was sent; or in nonblocking mode, this may only
	// indicate that the termination message was successfully queued. (in nonblocking mode, to be
	// certain that the data has been sent, you should next wait for write-ready and call `flush`,
	// repeating until it returns false.
	@(link_name="PQputCopyEnd")
	put_copy_end :: proc(conn: Conn, errormsg: cstring = nil) -> Put_Copy_Result ---
	
	// Receives data from the server during `COPY_OUT` state.
	//
	// Returned one row at a time.
	//
	// Successful return involves allocation of a chunk of memory to hold the data. The `buffer`
	// parameter must be non-nil. `buffer^` is set to point to the allocated memory, or to nil.
	// A non-nil buffer should be freed by the caller with `free_mem`.
	//
	// The return value is the length of the allocated buffer.
	// Zero is returned for in progress `COPY`'s when `async` is set to true.
	// -1 is returned when the `COPY` is done, call `get_result` to obtain the final result.
	// -2 is returned when an error occurred, consult `error_message` for the reason.
	//
	// When `async`, this will not block waiting for input, when 0 is returned, wait for read-ready
	// and then call `consume_input` before calling `get_copy_data` again.
	@(link_name="PQgetCopyData")
	get_copy_data :: proc(conn: Conn, buffer: ^[^]byte, async: b32) -> Get_Copy_Result ---


/*----- [[Control Functions; https://www.postgresql.org/docs/16/libpq-control.html]] -----*/
	
	// Returns the client encoding.
	//
	// Note that it returns the encoding ID, not a symbolic string. If unsuccessful, it returns -1.
	// To convert an encoding ID to an encoding name, use `encoding_to_char`.
	@(link_name="PQclientEncoding")
	client_encoding :: proc(conn: Conn) -> Encoding ---
	
	// Converts an encoding ID to a string name.
	@(link_name="pg_encoding_to_char")
	encoding_to_char :: proc(enc: Encoding) -> cstring ---
	
	// Sets the client encoding.
	@(link_name="PQsetClientEncoding")
	set_client_encoding :: proc(conn: Conn, encoding: cstring) -> Set_Encoding_Result ---
	
	// Determines the verbosity of messages returned by `error_message` and `result_error_message`.
	//
	// Returns the connection's previous settings.
	//
	// Setting the verbosity only changes next `Result` objects, not current ones. But you can use
	// `result_verbose_error_message` if you want to print a previous error with different verbosity.
	@(link_name="PQsetErrorVerbosity")
	set_error_verbosity :: proc(conn: Conn, verbosity: Verbosity) -> Verbosity ---
	
	// Determines the handling of `CONTEXT` fields in messages returned by `error_message` and
	// `result_error_message`.
	//
	// Returns the connection's previous settings.
	//
	// Setting this only changes next `Result` objects, not current ones. But you can use
	// `result_verbose_error_message` if you want to print a previous error with different visibility.
	@(link_name="PQsetErrorContextVisibility")
	set_error_context_visibility :: proc(conn: Conn, show_context: Context_Visibility) -> Context_Visibility ---
	
	// Enables tracing of the client/server communication to a debugging file stream.
	//
	// Each line consists of: an optional timestamp, a direction (F for client to server, B for server to client),
	// message length, message type, and message contents.
	//
	// Non-message content fields are separated by a tab. Message contents are separated by a space.
	// Protocol strings are enclosed in double quotes, while strings used as data values are enclosed
	// in single quotes. Non-printable chars are printed as hexadecimal escapes.
	// Further message-type-specific detail can be found in Section 55.7.
	trace :: proc(conn: Conn, stream: ^libc.FILE) ---
	
	// Controls the tracing behavior of the client/server communication.
	//
	// NOTE: this function must be called after `trace`.
	@(link_name="PQsetTraceFlags")
	set_trace_flags :: proc(conn: Conn, flags: Trace_Flags) ---
	
	// Disables the tracing started by `trace`.
	untrace :: proc(conn: Conn) ---


/*----- [[Miscellaneous Functions; https://www.postgresql.org/docs/16/libpq-misc.html]] -----*/
	
	// Frees memory allocated by libpq.
	//
	// It is particularly important that this function, rather than the default `free`, be used on
	// Windows. This is because allocating memory in a DLL and releasing it in the application works
	// only if multithreaded/single-threaded, release/debug, and static/dynamic flags are the same
	// for the DLL and the application. On non-Windows platforms, this function is the same as the
	// default `free`.
	@(link_name="PQfreemem")
	free_mem :: proc(ptr: rawptr) ---
	
	// Frees memory allocated by `conn_defaults` and `conninfo_parse`.
	//
	// A simple `free_mem` will not do for this, since the array contains references to subsidiary strings.
	@(link_name="PQconninfoFree")
	conninfo_free :: proc(conn_options: [^]Conninfo_Option) ---
	
	// Prepares the encrypted form of a PostgreSQL password.
	//
	// This function is intended to be used by client applications that wish to send commands like `ALTER USER joe PASSWORD 'pwd'`.
	// It is good practice not to send the original cleartext password in such a command,
	// because it might be exposed in command logs, activity displays, and so on.
	// Instead, use this function to convert the password to encrypted form before it is sent.
	//
	// The `passwd` and `user` arguments are the cleartext password, and the SQL name of the user it is for.
	// `algorithm` specifies the encryption algorithm to use to encrypt the password.
	// Currently supported algorithms are md5 and scram-sha-256 (on and off are also accepted as aliases for md5,
	// for compatibility with older server versions).
	// Note that support for scram-sha-256 was introduced in PostgreSQL version 10, and will not work correctly with older server versions.
	// If `algorithm` is NULL, this function will query the server for the current value of the `password_encryption` setting. That can block, and will fail if the current transaction is aborted, or if the connection is busy executing another query. If you wish to use the default algorithm for the server but want to avoid blocking, query password_encryption yourself before calling PQencryptPasswordConn, and pass that value as the algorithm.
	//
	// NOTE: The return value is a string allocated by `malloc`. Use PQfreemem to free the result when done with it. 
	//
	// The caller can assume the string doesn't contain any special characters that would require escaping.
	// On error, returns NULL, and a suitable message is stored in the connection object.
	@(link_name="PQencryptPasswordConn")
	encrypt_password_conn :: proc(conn: Conn, passwd: cstring, user: cstring, algorithm: cstring) -> cstring ---
	
	// Constructs an empty `Result` object with the given status.
	//
	// This is libpq's internal function to allocate and initialize an empty `Result` object.
	// This function returns NULL if memory could not be allocated.
	// It is exported because some applications find it useful to generate result objects (particularly objects with error status) themselves.
	// If conn is not null and status indicates an error, the current error message of the specified
	// connection is copied into the `Result`. Also, if conn is not null, any event procedures registered
	// in the connection are copied into the `Result`. (They do not get `PGEVT_RESULTCREATE` calls, but see `fire_result_create_events`.)
	// Note that `clear` should eventually be called on the object, just as with a `Result` returned by libpq itself.
	@(link_name="PQmakeEmptyPGResult")
	make_empty_result :: proc(conn: Conn, status: Exec_Status) -> Result ---
	
	// Fires a `PGEVT_RESULTCREATE` event for each event procedure registered in the `Result` object.
	@(link_name="PQfireResultCreateEvents")
	fire_result_create_events :: proc(conn: Conn, res: Result) -> b32 ---

	// Makes a copy of the `Result` object. The copy is not linked to the source result in any way
	// and `clear` must be called when it is no longer needed.
	//
	// Returns nil on failure.
	//
	// This is not intended to make an exact copy. The returned result is always put into `Tuples_Ok`
	// status, and does not copy any error message in the source. (It does copy the command status string, however.)
	// The `flags` argument determines what else is copied.
	@(link_name="PQcopyResult")
	copy_result :: proc(src: Result, flags: Result_Copy_Flags) -> Result ---
	
	// Sets the attributes of a `Result` object.
	@(link_name="PQsetResultAttrs")
	set_result_attrs :: proc(res: Result, num_attrs: i32, att_desc: [^]Res_Att_Desc) -> b32 ---
	
	// Sets a tuple field value of a `Result` object.
	@(link_name="PQsetvalue")
	set_value :: proc(res: Result, tup_num: i32, field_num: i32, value: [^]byte, len: i32) -> b32 ---
	
	// Allocate subsidiary storage for a `Result` object.
	//
	// Any memory allocated with this function will be freed when res is cleared.
	@(link_name="PQresultAlloc")
	result_alloc :: proc(res: Result, n_bytes: uint) -> [^]byte ---
	
	// Retrieves the number of bytes allocated for a `Result` object.
	//
	// This value is the sum of all `malloc` requests associated with the `Result` object, that is
	// all the space that will be freed by `clear`. This information can be useful for managing
	// memory consumption.
	@(link_name="PQresultMemorySize")
	result_memory_size :: proc(res: Result) -> uint ---
	
	// Returns the version of libpq that is being used.
	//
	// The result is formed by multiplying the library's major version number by 10_000 and adding
	// the minor version number. For example, version 10.1 will be returned as 100001, and version
	// 11.0 will be returned as 110000.
	//
	// Prior to version 10. PostgreSQL used three-part version numbers in which the first two parts
	// together represented the major version. For those versions, this function uses two digits for each part;
	// for example version 9.1.5 will be returned as 90105, and version 9.2.0 will be returned as 90200.
	//
	// Therefore, for purposes of determining feature compatibility, applications should divide the result
	// by 100, not 10_000, to determine a logical major version number. In all release series, only the
	// last two digits differ between minor releases (bug-fix releases).
	@(link_name="PQlibVersion")
	lib_version :: proc() -> i32 ---


/*----- [[Notice Processing; https://www.postgresql.org/docs/16/libpq-notice-processing.html]] -----*/

	// Notice and warning messages generated by the server are not returned by the query execution functions,
	// since they do not imply failure of the query. Instead they are passed to a notice handling function,
	// and execution continues normally after the handler returns.
	// The default notice handling function prints the message on stderr,
	// but the application can override this behavior by supplying its own handling function.
	//
	// For historical reasons, there are two levels of notice handling,
	// called the notice receiver and notice processor.
	// The default behavior is for the notice receiver to format the notice and pass a string to the notice processor for printing.
	// However, an application that chooses to provide its own notice receiver will typically ignore
	// the notice processor layer and just do all the work in the notice receiver.

	// Sets or examines the current notice receiver for a connection.
	//
	// Returns the previous notice receiver. If you supply a nil pointer receiver, the current
	// receiver is returned but not overwritten (basically a getter).
	@(link_name="PQsetNoticeReceiver")
	set_notice_receiver :: proc(conn: Conn, receiver: Notice_Receiver, user: rawptr) -> Notice_Receiver ---

	// Sets or examines the current notice processor for a connection.
	//
	// Returns the previous notice processor. If you supply a nil pointer processor, the current
	// processor is returned but not overwritten (basically a getter).
	@(link_name="PQsetNoticeProcessor")
	set_notice_processor :: proc(conn: Conn, processor: Notice_Processor, user: rawptr) -> Notice_Processor ---


/*----- [[Event System; https://www.postgresql.org/docs/16/libpq-events.html]] -----*/

	// libpq's event system is designed to notify registered event handlers about interesting libpq events,
	// such as the creation or destruction of `Conn` and `Result` objects.
	// A principal use case is that this allows applications to associate their own data with a `Conn` or
	// `Result` and ensure that that data is freed at an appropriate time.

	// Each registered event handler is associated with two pieces of data,
	// known to libpq only as opaque void * pointers.
	// There is a pass-through pointer that is provided by the application when the event handler is
	// registered with a `Conn`.
	// The pass-through pointer never changes for the life of the `Conn` and all `Result`'s generated from it;
	// so if used, it must point to long-lived data.
	// In addition there is an instance data pointer, which starts out NULL in every `Conn` and `Result`.
	// This pointer can be manipulated using the `instance_data`, `set_instance_data`, `result_instance_data`
	// and `result_set_instance_data functions.
	// Note that unlike the pass-through pointer, instance data of a `Conn` is not automatically inherited by
	// `Result`'s created from it.
	// libpq does not know what pass-through and instance data pointers point to (if anything) and will never
	// attempt to free them — that is the responsibility of the event handler.

	// Registers an event callback procedure with libpq.
	//
	// An event procedure must be registered once on each `Conn` you want to receive events about.
	// There is no limit, other than memory, on the number of event procedures that can be registered with a connection.
	//
	// The `func` argument will be called when a libpq event is fired. Its memory address is also used
	// to lookup `instance_data`. The `name` argument is used to refer to the event procedure in error messages.
	// This value cannot be nil or a zero-length string. The name string is copied into the `Conn`, so what
	// is passed need not be long-lived. The `pass_through` pointer is passed to the `func` whenever an event occurs.
	@(link_name="PQregisterEventProc")
	register_event_proc :: proc(conn: Conn, func: Event_Proc, name: cstring, pass_through: rawptr) -> b32 ---
	
		
	// Sets the connection `Conn`'s `instance_data` for procedure `func` to `data`.
	// Fails if `func` is not registered on the `Conn`.
	@(link_name="PQsetInstanceData")
	set_instance_data :: proc(conn: Conn, func: Event_Proc, data: rawptr) -> b32 ---
	
	// Returns the `conn`'s `instance_data` associated with procedure `func`, or nil if there is none.
	@(link_name="PQinstanceData")
	instance_data :: proc(conn: Conn, func: Event_Proc) -> rawptr ---
	
	// Sets the result's `instance_data` for `func` to `data`.
	// Fails if `func` is not registered on the `Conn`.
	// Beware that any storage represented by `data` will not be accounted for by `result_memory_size`,
	// unless it is allocated using `result_alloc`. (Doing so is recommendable because it eliminates the
	// need to free such storage explicitly when the result is destroyed.)
	@(link_name="PQresultSetInstanceData")
	result_set_instance_data :: proc(res: Result, func: Event_Proc, data: rawptr) -> b32 ---
	
	// Returns the result's `instance_data` associated with `func`, or nil if there is none.
	@(link_name="PQresultInstanceData")
	result_instance_data :: proc(res: Result, func: Event_Proc) -> rawptr ---
}
