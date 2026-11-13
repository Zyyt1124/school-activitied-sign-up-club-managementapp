package campus.service

import std.collection.*
import campus.domain.*
import campus.repository.*

public class ClubService {
    private let users: UserRepository
    private let clubs: ClubRepository
    private let tx: TxRunner
    private let clock: Clock

    public init(
        users: UserRepository,
        clubs: ClubRepository,
        tx: TxRunner,
        clock: Clock
    ) {
        this.users = users
        this.clubs = clubs
        this.tx = tx
        this.clock = clock
    }

    public func createClub(actor: Actor, clubName: String, intro: String): Outcome<Club, BizError> {
        return tx.run<Outcome<Club, BizError>>({ =>
            if (clubName.size == 0) {
                return fail<Club>(invalidError("INVALID_CLUB_NAME", "社团名称不能为空"))
            }
            let status = match (actor.role) {
                case Admin => Active
                case Student | ClubLeader => Pending
            }
            let club = clubs.create(clubName, intro, actor.userId, status, clock.nowMillis())
            succeed<Club>(club)
        })
    }

    public func approveClub(actor: Actor, clubId: Int64): Outcome<Club, BizError> {
        return tx.run<Outcome<Club, BizError>>({ =>
            match (requireAdmin(actor)) {
                case Some(error) => return fail<Club>(error)
                case None => ()
            }
            match (clubs.find(clubId)) {
                case None => fail<Club>(notFoundError("CLUB_NOT_FOUND", "社团不存在"))
                case Some(club) =>
                    let pending = match (club.status) {
                        case Pending => true
                        case Active | Disabled => false
                    }
                    if (!pending) {
                        return fail<Club>(conflictError("CLUB_NOT_PENDING", "社团不在待审核状态"))
                    }
                    club.status = Active
                    clubs.save(club)

                    match (users.find(club.leaderId)) {
                        case Some(leader) =>
                            leader.role = ClubLeader
                            users.save(leader)
                        case None => ()
                    }
                    succeed<Club>(club)
            }
        })
    }

    public func disableClub(actor: Actor, clubId: Int64): Outcome<Club, BizError> {
        return tx.run<Outcome<Club, BizError>>({ =>
            match (requireAdmin(actor)) {
                case Some(error) => return fail<Club>(error)
                case None => ()
            }
            match (clubs.find(clubId)) {
                case None => fail<Club>(notFoundError("CLUB_NOT_FOUND", "社团不存在"))
                case Some(club) =>
                    club.status = Disabled
                    clubs.save(club)
                    succeed<Club>(club)
            }
        })
    }

    public func find(clubId: Int64): Option<Club> {
        return clubs.find(clubId)
    }

    public func listActive(): ArrayList<Club> {
        let result = ArrayList<Club>()
        for (club in clubs.list()) {
            match (club.status) {
                case Active => result.add(club)
                case Pending | Disabled => ()
            }
        }
        return result
    }
}
