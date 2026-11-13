package campus.repository

import std.collection.*
import std.sync.*
import campus.domain.*

/**
 * 课程演示用的内存数据源。
 *
 * 这里刻意不写 SQL：SQL 适配器只需要实现同样的 Repository 接口，
 * service 层一行都不用改。MemoryRepositories 把「数据」和「仓储」
 * 分开，避免一个类同时实现多个同名 find/list 造成重载冲突。
 */
public class MemoryDb {
    public let lock = Mutex()

    public let users = HashMap<Int64, User>()
    public let usersByStudentId = HashMap<String, User>()
    public let clubs = HashMap<Int64, Club>()
    public let activities = HashMap<Int64, Activity>()
    public let signsByActivity = HashMap<Int64, ArrayList<SignRecord>>()
    public let signById = HashMap<Int64, SignRecord>()
    public let signByKey = HashMap<String, SignRecord>()
    public let messages = HashMap<Int64, ArrayList<Message>>()

    private var nextUser = 0
    private var nextClub = 0
    private var nextActivity = 0
    private var nextSign = 0
    private var nextMessage = 0

    public func withLock<T>(body: () -> T): T {
        synchronized(lock) {
            return body()
        }
    }

    public func nextUserId(): Int64 {
        nextUser += 1
        return nextUser
    }

    public func nextClubId(): Int64 {
        nextClub += 1
        return nextClub
    }

    public func nextActivityId(): Int64 {
        nextActivity += 1
        return nextActivity
    }

    public func nextSignId(): Int64 {
        nextSign += 1
        return nextSign
    }

    public func nextMessageId(): Int64 {
        nextMessage += 1
        return nextMessage
    }
}

public class MemoryTxRunner <: TxRunner {
    private let db: MemoryDb

    public init(db: MemoryDb) {
        this.db = db
    }

    public func run<T>(body: () -> T): T {
        return db.withLock(body)
    }
}

public class MemoryUserRepository <: UserRepository {
    private let db: MemoryDb

    public init(db: MemoryDb) {
        this.db = db
    }

    public func find(userId: Int64): Option<User> {
        return db.users.get(userId)
    }

    public func findByStudentId(studentId: String): Option<User> {
        return db.usersByStudentId.get(studentId)
    }

    public func save(user: User): Unit {
        db.users[user.userId] = user
        db.usersByStudentId[user.studentId] = user
    }
}

public class MemoryClubRepository <: ClubRepository {
    private let db: MemoryDb

    public init(db: MemoryDb) {
        this.db = db
    }

    public func find(clubId: Int64): Option<Club> {
        return db.clubs.get(clubId)
    }

    public func findByLeader(leaderId: Int64): Option<Club> {
        for ((_, club) in db.clubs) {
            if (club.leaderId == leaderId) {
                return Some(club)
            }
        }
        return None
    }

    public func create(
        clubName: String,
        intro: String,
        leaderId: Int64,
        status: ClubStatus,
        createdAt: Int64
    ): Club {
        let club = Club(db.nextClubId(), clubName, intro, leaderId, status, createdAt)
        db.clubs[club.clubId] = club
        return club
    }

    public func save(club: Club): Unit {
        db.clubs[club.clubId] = club
    }

    public func list(): ArrayList<Club> {
        let result = ArrayList<Club>()
        for ((_, club) in db.clubs) {
            result.add(club)
        }
        return result
    }
}

public class MemoryActivityRepository <: ActivityRepository {
    private let db: MemoryDb

    public init(db: MemoryDb) {
        this.db = db
    }

    public func find(activityId: Int64): Option<Activity> {
        return db.activities.get(activityId)
    }

    public func create(
        clubId: Int64,
        title: String,
        description: String,
        location: String,
        maxCount: Int64,
        signStart: Int64,
        signEnd: Int64,
        activityTime: Int64,
        state: ActivityState
    ): Activity {
        let activity = Activity(
            db.nextActivityId(),
            clubId,
            title,
            description,
            location,
            maxCount,
            maxCount,
            signStart,
            signEnd,
            activityTime,
            state,
            0
        )
        db.activities[activity.activityId] = activity
        return activity
    }

    public func save(activity: Activity): Unit {
        db.activities[activity.activityId] = activity
    }

    public func list(): ArrayList<Activity> {
        let result = ArrayList<Activity>()
        for ((_, activity) in db.activities) {
            result.add(activity)
        }
        return result
    }

    public func tryReserveSeat(activityId: Int64): Bool {
        match (db.activities.get(activityId)) {
            case None => false
            case Some(activity) =>
                if (isOpenState(activity.state) && activity.remainCount > 0) {
                    activity.remainCount -= 1
                    activity.version += 1
                    return true
                }
                return false
        }
    }

    public func releaseSeat(activityId: Int64): Unit {
        match (db.activities.get(activityId)) {
            case None => ()
            case Some(activity) =>
                if (activity.remainCount < activity.maxCount) {
                    activity.remainCount += 1
                    activity.version += 1
                }
        }
    }
}

public class MemorySignRepository <: SignRepository {
    private let db: MemoryDb

    public init(db: MemoryDb) {
        this.db = db
    }

    public func findActive(activityId: Int64, userId: Int64): Option<SignRecord> {
        match (db.signsByActivity.get(activityId)) {
            case None => None
            case Some(records) =>
                for (record in records) {
                    if (record.userId == userId && !record.cancelled) {
                        return Some(record)
                    }
                }
                None
        }
    }

    public func findLatest(activityId: Int64, userId: Int64): Option<SignRecord> {
        match (db.signsByActivity.get(activityId)) {
            case None => None
            case Some(records) =>
                var latest: Option<SignRecord> = None
                for (record in records) {
                    if (record.userId == userId) {
                        latest = Some(record)
                    }
                }
                latest
        }
    }

    public func findByIdempotencyKey(key: String): Option<SignRecord> {
        return db.signByKey.get(key)
    }

    public func create(activityId: Int64, userId: Int64, signTime: Int64, idempotencyKey: String): SignRecord {
        let record = SignRecord(
            db.nextSignId(),
            activityId,
            userId,
            signTime,
            false,
            false,
            idempotencyKey
        )
        db.signById[record.signId] = record
        if (idempotencyKey.size > 0) {
            db.signByKey[idempotencyKey] = record
        }
        match (db.signsByActivity.get(activityId)) {
            case Some(records) => records.add(record)
            case None =>
                let records = ArrayList<SignRecord>()
                records.add(record)
                db.signsByActivity[activityId] = records
        }
        return record
    }

    public func cancel(signId: Int64): Unit {
        match (db.signById.get(signId)) {
            case None => ()
            case Some(record) => record.cancelled = true
        }
    }

    public func markCheckedIn(signId: Int64): Bool {
        match (db.signById.get(signId)) {
            case None => false
            case Some(record) =>
                record.checkedIn = true
                return true
        }
    }

    public func listByActivity(activityId: Int64): ArrayList<SignRecord> {
        let result = ArrayList<SignRecord>()
        match (db.signsByActivity.get(activityId)) {
            case None => ()
            case Some(records) =>
                for (record in records) {
                    if (!record.cancelled) {
                        result.add(record)
                    }
                }
        }
        return result
    }
}

public class MemoryMessageRepository <: MessageRepository {
    private let db: MemoryDb

    public init(db: MemoryDb) {
        this.db = db
    }

    public func create(
        userId: Int64,
        title: String,
        content: String,
        messageType: String,
        createdAt: Int64
    ): Message {
        let message = Message(
            db.nextMessageId(),
            userId,
            title,
            content,
            messageType,
            false,
            createdAt
        )
        match (db.messages.get(userId)) {
            case Some(list) => list.add(message)
            case None =>
                let list = ArrayList<Message>()
                list.add(message)
                db.messages[userId] = list
        }
        return message
    }

    public func listByUser(userId: Int64): ArrayList<Message> {
        let result = ArrayList<Message>()
        match (db.messages.get(userId)) {
            case None => ()
            case Some(list) =>
                for (message in list) {
                    result.add(message)
                }
        }
        return result
    }

    public func markRead(messageId: Int64, userId: Int64): Bool {
        for ((_, list) in db.messages) {
            for (message in list) {
                if (message.messageId == messageId && message.userId == userId) {
                    message.read = true
                    return true
                }
            }
        }
        return false
    }
}

/**
 * 一组内存仓储。service 只拿到接口，不关心后面是 HashMap 还是 SQL。
 */
public class MemoryRepositories {
    public let db: MemoryDb
    public let users: UserRepository
    public let clubs: ClubRepository
    public let activities: ActivityRepository
    public let signs: SignRepository
    public let messages: MessageRepository
    public let tx: TxRunner

    public init() {
        let db = MemoryDb()
        this.db = db
        this.users = MemoryUserRepository(db)
        this.clubs = MemoryClubRepository(db)
        this.activities = MemoryActivityRepository(db)
        this.signs = MemorySignRepository(db)
        this.messages = MemoryMessageRepository(db)
        this.tx = MemoryTxRunner(db)
    }
}

/**
 * 演示数据：三个角色各一个账号，密码统一为 123456。
 * 真实环境必须由管理员导入或走校园统一身份认证，不能硬编码。
 */
public func seedDemoData(repos: MemoryRepositories, nowMillis: Int64): Unit {
    let admin = User(repos.db.nextUserId(), "admin", "学校管理员", Admin, "学生工作处", "", "demo:123456")
    let leader = User(repos.db.nextUserId(), "leader", "林同学", ClubLeader, "计算机学院", "13800000002", "demo:123456")
    let student = User(repos.db.nextUserId(), "student", "朱同学", Student, "软件学院", "13800000003", "demo:123456")
    let second = User(repos.db.nextUserId(), "student2", "严同学", Student, "外国语学院", "13800000004", "demo:123456")
    repos.users.save(admin)
    repos.users.save(leader)
    repos.users.save(student)
    repos.users.save(second)

    let club = Club(
        repos.db.nextClubId(),
        "开源技术社",
        "面向全校的技术分享与开源实践社团。",
        leader.userId,
        Active,
        nowMillis
    )
    repos.clubs.save(club)

    let hour = 3600 * 1000
    let day = 24 * hour

    let first = Activity(
        repos.db.nextActivityId(),
        club.clubId,
        "鸿蒙原生应用开发分享会",
        "从 Stage 模型到端云协同，带你把一个校园应用从 0 跑通。",
        "图书馆报告厅",
        50,
        50,
        nowMillis - hour,
        nowMillis + 7 * day,
        nowMillis + 8 * day,
        Open,
        0
    )
    repos.activities.save(first)

    let secondActivity = Activity(
        repos.db.nextActivityId(),
        club.clubId,
        "仓颉语言入门工作坊",
        "类型系统、模式匹配、事务边界：用仓颉写一遍报名业务。",
        "实验楼 A305",
        30,
        30,
        nowMillis - hour,
        nowMillis + 5 * day,
        nowMillis + 6 * day,
        Open,
        0
    )
    repos.activities.save(secondActivity)

    let third = Activity(
        repos.db.nextActivityId(),
        club.clubId,
        "校园社团招新市集",
        "全校社团集中摆摊，现场咨询、扫码报名、领取社团手册。",
        "中心广场",
        200,
        200,
        nowMillis - hour,
        nowMillis + 3 * day,
        nowMillis + 4 * day,
        Open,
        0
    )
    repos.activities.save(third)
}
