import { ActivityState } from '../common/models';
import { AppColors } from '../common/constants/AppTheme';

@Component
export struct StateTag {
  @Prop state: ActivityState;

  private label(): string {
    switch (this.state) {
      case ActivityState.DRAFT:
        return '草稿';
      case ActivityState.OPEN:
        return '报名中';
      case ActivityState.CLOSED:
        return '报名结束';
      case ActivityState.ARCHIVED:
        return '已结束';
      case ActivityState.DISABLED:
        return '已下架';
      default:
        return '未知';
    }
  }

  private textColor(): string {
    switch (this.state) {
      case ActivityState.OPEN:
        return AppColors.success;
      case ActivityState.DISABLED:
        return AppColors.danger;
      case ActivityState.CLOSED:
      case ActivityState.ARCHIVED:
        return AppColors.muted;
      default:
        return AppColors.orange;
    }
  }

  private tagBackground(): string {
    switch (this.state) {
      case ActivityState.OPEN:
        return '#EAF5EE';
      case ActivityState.DISABLED:
        return '#FBECEA';
      case ActivityState.CLOSED:
      case ActivityState.ARCHIVED:
        return AppColors.bg;
      default:
        return '#FBF1E8';
    }
  }

  build() {
    Text(this.label())
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.textColor())
      .backgroundColor(this.tagBackground())
      .borderRadius(6)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
  }
}
