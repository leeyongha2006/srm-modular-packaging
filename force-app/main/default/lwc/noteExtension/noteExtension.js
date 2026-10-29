/**
 * 예제 모듈 2: 등록 속성(heading)만 받아 그리는 가장 단순한 확장.
 */
import { LightningElement, api } from "lwc";

export default class NoteExtension extends LightningElement {
    @api recordId;
    @api heading = "Notes";
}