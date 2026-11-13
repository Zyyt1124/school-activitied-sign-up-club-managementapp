package campus.domain

public enum Role {
    | Student
    | ClubLeader
    | Admin
}

public enum ActivityState {
    | Draft
    | Open
    | Closed
    | Archived
    | Disabled
}

public enum ClubStatus {
    | Pending
    | Active
    | Disabled
}

public class User {
    public let userId: Int64
    public let studentId: String
    public var name: String
    public var role: Role
    public var college: String
    public var phone: String
    public let passwordHash: String

    public init(
        userId: Int64,
        studentId: String,
        name: String,
        role: Role,
        college: String,
        phone: String,
        passwordHash: String
    ) {
        this.userId = userId
        this.studentId = studentId
        this.name = name
        this.role = role
        this.college = college
        this.phone = phone
        this.passwordHash = passwordHash
    }
}

public class Club {
    public let clubId: Int64
    public var clubName: String
    public var intro: String
    public var leaderId: Int64
    public var status: ClubStatus
    public let createdAt: Int64

    public init(
        clubId: Int64,
        clubName: String,
        intro: String,
        leaderId: Int64,
        status: ClubStatus,
        createdAt: Int64
    ) {
        this.clubId = clubId
        this.clubName = clubName
        this.intro = intro
        this.leaderId = leaderId
        this.status = status
        this.createdAt = createdAt
    }
}

public class Activity {
    public let activityId: Int64
    public let clubId: Int64
    public var title: String
    public var description: String
    public var location: String
    public var maxCount: Int64
    public var remainCount: Int64
    public let signStart: Int64
    public let signEnd: Int64
    public let activityTime: Int64
    public var state: ActivityState
    public var version: Int64

    public init(
        activityId: Int64,
        clubId: Int64,
        title: String,
        description: String,
        location: String,
        maxCount: Int64,
        remainCount: Int64,
        signStart: Int64,
        signEnd: Int64,
        activityTime: Int64,
        state: ActivityState,
        version: Int64
    ) {
        this.activityId = activityId
        this.clubId = clubId
        this.title = title
        this.description = description
        this.location = location
        this.maxCount = maxCount
        this.remainCount = remainCount
        this.signStart = signStart
        this.signEnd = signEnd
        this.activityTime = activityTime
        this.state = state
        this.version = version
    }
}

public class SignRecord {
    public let signId: Int64
    public let activityId: Int64
    public let userId: Int64
    public let signTime: Int64
    public var cancelled: Bool
    public var checkedIn: Bool
    public let idempotencyKey: String

    public init(
        signId: Int64,
        activityId: Int64,
        userId: Int64,
        signTime: Int64,
        cancelled: Bool,
        checkedIn: Bool,
        idempotencyKey: String
    ) {
        this.signId = signId
        this.activityId = activityId
        this.userId = userId
        this.signTime = signTime
        this.cancelled = cancelled
        this.checkedIn = checkedIn
        this.idempotencyKey = idempotencyKey
    }
}

public class Message {
    public let messageId: Int64
    public let userId: Int64
    public let title: String
    public let content: String
    public let messageType: String
    public var read: Bool
    public let createdAt: Int64

    public init(
        messageId: Int64,
        userId: Int64,
        title: String,
        content: String,
        messageType: String,
        read: Bool,
        createdAt: Int64
    ) {
        this.messageId = messageId
        this.userId = userId
        this.title = title
        this.content = content
        this.messageType = messageType
        this.read = read
        this.createdAt = createdAt
    }
}

/**
 * 一次请求里的调用者身份。
 *
 * leaderClubId 只在 role 为 ClubLeader 时有值。把「是谁」和「能做什么」
 * 分开：Actor 由鉴权层构造，权限判断集中在 service 层。
 */
public class Actor {
    public let userId: Int64
    public let role: Role
    public let leaderClubId: Option<Int64>

    public init(userId: Int64, role: Role, leaderClubId: Option<Int64>) {
        this.userId = userId
        this.role = role
        this.leaderClubId = leaderClubId
    }
}

public class SignUpReceipt {
    public let signId: Int64
    public let activityId: Int64
    public let userId: Int64
    public let signTime: Int64
    public let remainCount: Int64

    public init(
        signId: Int64,
        activityId: Int64,
        userId: Int64,
        signTime: Int64,
        remainCount: Int64
    ) {
        this.signId = signId
        this.activityId = activityId
        this.userId = userId
        this.signTime = signTime
        this.remainCount = remainCount
    }
}

public class LoginResult {
    public let token: String
    public let user: User

    public init(token: String, user: User) {
        this.token = token
        this.user = user
    }
}
