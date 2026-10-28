import RecallInput from "./RecallInput";

export default function QuickQuestion({ cardId, question, answer, explanation }: { cardId: string; question: string; answer: string; explanation: string }) {
  return <section id="questions" className="quick-question">
    <div className="study-section-head"><span>STEP 2</span><div><h2>한 가지만 떠올려 보기</h2><p>먼저 내 생각을 적고, 예시 답과 비교해 보세요. 말로 답해도 괜찮아요.</p></div></div>
    <p className="quick-question-prompt">{question}</p>
    <RecallInput storageKey={`jobStudy::quick::${cardId}`} label="떠올린 답변" />
    <details className="answer-guide">
      <summary>예시 답과 비교하기</summary>
      <div className="quick-answer"><strong>예시 답</strong><p>{answer}</p><strong>왜 이렇게 답할까요?</strong><p>{explanation}</p><p className="hint">내가 떠올린 답과 어떤 점이 같고 다른지 비교해 보세요.</p></div>
    </details>
    <a className="recall-next" href="#complete">이해도 기록하고 마치기 <span aria-hidden="true">→</span></a>
  </section>;
}
