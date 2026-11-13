package campus.repository

import std.collection.*
import campus.domain.*

public interface UserRepository {
    func find(userId: Int64): Option<User>
    func findByStudentId(studentId: String): Option<User>
    func save(user: User): Unit
}

public interface ClubRepository {
    func find(clubId: Int64): Option<Club>
    func findByLeader(leaderId: Int64): Option<Club>
    func create(clubName: String, intro: String, leaderId: Int64, status: ClubStatus, createdAt: Int64): Club
    func save(club: Club): Unit
    func list(): ArrayList<Club>
}

public interface ActivityRepository {
    func find(activityId: Int64): Option<Activity>
    func create(
        clubId: Int64,
        title: String,
        description: String,
        location: String,
        maxCount: Int64,
        signStart: Int64,
        signEnd: Int64,
        activityTime: Int64,
        state: ActivityState
    ): Activity
    func save(activity: Activity): Unit
    func list(): ArrayList<Activity>

    /**
     * 原子占一个名额。
     *
     * 内存实现用调用方的事务锁保证；SQL 实现对应：
     *   UPDATE activity SET remain_count = remain_count - 1, version = version + 1
     *   WHERE activity_id = ? AND remain_count > 0 AND status = 'open'
     * 返回 rowcount == 1 即成功。
     */
    func tryReserveSeat(activityId: Int64): Bool

    /**
     * 归还一个名额，SQL 实现需要带上 remain_count < max_count 的条件。
     */
    func releaseSeat(activityId: Int64): Unit
}

public interface SignRepository {
    func findActive(activityId: Int64, userId: Int64): Option<SignRecord>
    func findLatest(activityId: Int64, userId: Int64): Option<SignRecord>
    func findByIdempotencyKey(key: String): Option<SignRecord>
    func create(activityId: Int64, userId: Int64, signTime: Int64, idempotencyKey: String): SignRecord
    func cancel(signId: Int64): Unit
    func markCheckedIn(signId: Int64): Bool
    func listByActivity(activityId: Int64): ArrayList<SignRecord>
}

public interface MessageRepository {
    func create(
        userId: Int64,
        title: String,
        content: String,
        messageType: String,
        createdAt: Int64
    ): Message
    func listByUser(userId: Int64): ArrayList<Message>
    func markRead(messageId: Int64, userId: Int64): Bool
}

/**
 * 事务边界。
 *
 * 服务层只依赖这个接口：
 *  - 内存实现用 Mutex 包住一次业务操作
 *  - SQL 实现开始事务、执行 body、提交或回滚
 *
 * 这样业务代码完全不知道底层是内存还是 PostgreSQL / GaussDB。
 */
public interface TxRunner {
    func run<T>(body: () -> T): T
}
