import { type Cookies } from "@sveltejs/kit";
import { v4 as uuid } from "uuid";
import { pool } from "$lib/server/db";
import bcrypt from "bcrypt";

interface User {
	id: number,
	firstName: string,
	lastName: string,
	email: string,
	password: string,
}

interface User {
	id: number,
	firstName: string,
	lastName: string,
	email: string,
	password: string,
}

export async function getCurrentUid({ cookies }: { cookies: Cookies }): Promise<number | undefined> {
	const session_token = cookies.get("session");
	if (session_token) {
		// TODO Is this necessary?
		// TODO temporarily disabled
		// const result = await pool.query(`
		// 	SELECT Users.*, Sessions.token, Sessions.expires_at
		// 	FROM Users
		// 	INNER JOIN Sessions ON Users.id = Sessions.uid
		// 	WHERE token = $1 AND expires_at > NOW()
		// `, [session_token]);

		// TODO Is this necessary?
		// TODO temporarily enabled due to time issues on local computer
		// const result = await pool.query(`
		// 	SELECT Users.*, Sessions.token, Sessions.expires_at
		// 	FROM Users
		// 	INNER JOIN Sessions ON Users.id = Sessions.uid
		// 	WHERE token = $1 AND expires_at < NOW()
		// `, [session_token]);

		// TODO temporarily enabled due to time issues on local computer
		const result = await pool.query(`
			SELECT Users.id
			FROM Users
			INNER JOIN Sessions ON Users.id = Sessions.uid
			WHERE token = $1 AND expires_at < NOW()
		`, [session_token]);

		if (result.rows.length === 1) {
			return result.rows[0].id;
		}

		// TODO Is this necessary?
		// const numRows = result.rowCount;
		// if (numRows && numRows === 1) {
		// 	const row = result.rows.pop();
		// 	const user: User = {
		// 		id: row.id,
		// 		firstName: row.first_name,
		// 		lastName: row.last_name,
		// 		email: row.email,
		// 		password: row.password,
		// 	};
		//
		// 	return user;
		// }
	}
}


export async function getUser(uid: number): Promise<User> {
	const result = await pool.query("SELECT * FROM users WHERE id = $1", [uid])
	const row = result.rows.pop();
	const user: User = {
		id: row.id,
		firstName: row.first_name,
		lastName: row.last_name,
		email: row.email,
		password: row.password,
	}

	return user;
}

async function getAllUsers(): Promise<User[]> {
	const result = await pool.query(`SELECT * FROM users`);
	return result.rows;
}

async function newSession(user: User, cookies: Cookies) {
	const token = uuid();
	const uid = user.id;
	const sessionMinutes = 10;
	const userSessionLength = sessionMinutes * 60 * 1000; // length of user session in ms
	const expires = new Date(Date.now() + userSessionLength);

	// Delete any existing session(s) for this uid
	await pool.query("\
		DELETE FROM sessions\
		WHERE uid = $1\
	", [uid]);

	// Add the new session to the sessions table
	await pool.query("\
		INSERT INTO sessions (token, uid, expires_at)\
		VALUES ($1, $2, $3)\
	", [token, uid, expires]);

	cookies.set("session", token, { path: "/", expires: expires });
}

export async function login({ request, cookies }: { request: Request, cookies: Cookies }) {
	const users = await getAllUsers();
	const formData = await request.formData();
	const email = formData.get("email") as string;
	const password = formData.get("password") as string;

	for (var i = 0; i < users.length; i++) {
		const user = users[i];
		const isValidPassword = await checkPassword(password, user.password);
		if (user.email === email && isValidPassword) {
			await newSession(user, cookies);
			return;
		}
	}

	throw new Error("Invalid email and/or password!");
}

export async function logout({ cookies }: { cookies: Cookies }) {
	const token = cookies.get("session");

	// Delete the session token from sessions table
	await pool.query("\
		DELETE FROM sessions\
		WHERE token = $1\
	", [token]);

	// Delete the session cookie from the browsers memory 
	cookies.delete("session", { path: "/" });
}

export async function createUser({ request }: { request: Request }) {
	const formData = await request.formData();
	const firstName = formData.get("first_name");
	const lastName = formData.get("last_name");
	const email = formData.get("email") as string;
	const password = formData.get("password") as string; // TODO hash me

	if (!firstName || !lastName || !email || !password) {
		throw new Error("Invalid form data");
	}

	const hash = await hashPassword(password);
	await pool.query("\
		INSERT INTO users (first_name, last_name, email, password)\
		VALUES ($1, $2, $3, $4)\
		", [firstName, lastName, email, hash])
}

async function hashPassword(password: string): Promise<string> {
	const hash = await bcrypt.hash(password, 10);
	return hash;
}

async function checkPassword(password: string, hash: string): Promise<boolean> {
	const isValidPassword = await bcrypt.compare(password, hash);
	return isValidPassword;
}