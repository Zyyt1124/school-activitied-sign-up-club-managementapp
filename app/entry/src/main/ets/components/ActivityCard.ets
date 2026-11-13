import { ActivitySummary } from '../common/models';
import { AppColors, AppSpace, AppText } from '../common/constants/AppTheme';
import { formatShortDate } from '../common/utils/DateFormat';
import { StateTag } from './StateTag';

@Component
export struct ActivityCard {
  @Prop activity: ActivitySummary;
  onTap: () => void = () => {
  };

  build() {
    Column({ space: 10 }) {
      Row() {
        Text(this.activity.title)
          .fontSize(AppText.section)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.ink)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        StateTag({ state: this.activity.state })
      }
      .width('100%')

      Text(this.activity.clubName)
        .fontSize(AppText.caption)
        .fontColor(AppColors.blue)

      Row({ space: 6 }) {
        Text('时间')
          .fontSize(AppText.caption)
          .fontColor(AppColors.muted)
        Text(formatShortDate(this.activity.activityTime))
          .fontSize(AppText.caption)
          .fontColor(AppColors.inkSecondary)
          .layoutWeight(1)
      }
      .width('100%')

      Row() {
        Text(this.activity.location)
          .fontSize(AppText.caption)
          .fontColor(AppColors.muted)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(`剩余 ${this.activity.remainCount} / ${this.activity.maxCount}`)
          .fontSize(AppText.caption)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.activity.remainCount > 0 ? AppColors.orange : AppColors.muted)
      }
      .width('100%')
    }
    .width('100%')
    .padding(AppSpace.card)
    .backgroundColor(AppColors.white)
    .borderRadius(AppSpace.radius)
    .onClick(() => {
      this.onTap();
    })
  }
}
