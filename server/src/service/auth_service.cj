package campus.service

import std.collection.*
import campus.domain.*
import campus.repository.*

public interface PasswordVerifier {
    func verify(raw: String, stored: String): Bool
}

/**
 * 演示用密码校验。真实环境应使用 Argon2id / bcrypt，
 * 并且密码哈希只在服务端保存，绝不能下发到端侧。
 */
public class DemoPasswordVerifier <: PasswordVerifier {
    public func verify(raw: String, stored: String): Bool {
        return stored == "demo:${raw}"
    }
}

public interface TokenService {
    func issue(actor: Actor): String
    func actorOf(token: String): Option<Actor>
    func revoke(token: String): Unit
}

/**
 * 演示用会话表。生产环境换成带过期时间、可主动失效的 JWT / 会话服务。
 */
public class InMemoryTokenService <: TokenService {
    private let sessions = HashMap<String, Actor>()
    private var counter: Int64 = 0

    public func issue(actor: Actor): String {
        counter += 1
        let token = "demo-token-${actor.userId}-${counter}"
        sessions[token] = actor
        return token
    }

    public func actorOf(token: String): Option<Actor> {
        return sessions.get(token)
    }

    public func revoke(token: String): Unit {
        sessions.remove(token)
    }
}

public class AuthService {
    private let users: UserRepository
    private let clubs: ClubRepository
    private let passwords: PasswordVerifier
    private let tokens: TokenService

    public init(
        users: UserRepository,
        clubs: ClubRepository,
        passwords: PasswordVerifier,
        tokens: TokenService
    ) {
        this.users = users
        this.clubs = clubs
        this.passwords = passwords
        this.tokens = tokens
    }

    public func login(studentId: String, password: String): Outcome<LoginResult, BizError> {
        match (users.findByStudentId(studentId)) {
            case None => fail<LoginResult>(unauthorizedError("BAD_CREDENTIALS", "学号或密码错误"))
            case Some(user) =>
                if (!passwords.verify(password, user.passwordHash)) {
                    return fail<LoginResult>(unauthorizedError("BAD_CREDENTIALS", "学号或密码错误"))
                }
                let leaderClubId: Option<Int64> = match (clubs.findByLeader(user.userId)) {
                    case Some(club) => Some(club.clubId)
                    case None => None
                }
                let actor = Actor(user.userId, user.role, leaderClubId)
                let token = tokens.issue(actor)
                succeed<LoginResult>(LoginResult(token, user))
        }
    }

    public func authenticate(token: String): Option<Actor> {
        return tokens.actorOf(token)
    }

    public func logout(token: String): Unit {
        tokens.revoke(token)
    }
}
