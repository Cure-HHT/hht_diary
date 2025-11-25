import React from 'react';
import { QuestionnaireData } from '../components/QuestionnaireFlow';

// PLACEHOLDER DATA - REPLACE WITH CSV IMPORTS
// 
// To replace this data with actual CSV files:
// 1. Place your CSV files in this /data directory
// 2. Import and parse the CSV data using a CSV parsing library
// 3. Transform the CSV data to match the QuestionnaireData interface
// 
// Expected CSV structure:
// Preamble CSV: id, content
// Questions CSV: id, question, option1, option2, option3, option4, option5, required
//
// Example CSV imports:
// import noseStudyPreambleCsv from './nose-study-preamble.csv';
// import noseStudyQuestionsCsv from './nose-study-questions.csv';
// import qualityOfLifePreambleCsv from './quality-of-life-preamble.csv';
// import qualityOfLifeQuestionsCsv from './quality-of-life-questions.csv';
export const noseStudyQuestionnaire: QuestionnaireData = {
  name: "NOSE HHT",
  preamble: [
    {
      id: "nose_preamble_1",
      content: "Nasal Outcome Score for Epistaxis in Hereditary Hemorrhagic Telangiectasia\n\nBelow you will find a list of physical, functional, and emotional consequences of your nosebleeds. We would like to know more about these problems and would appreciate you answering the following questions to the best of your ability."
    },
    {
      id: "nose_preamble_2",
      content: "There are no right or wrong answers, as your responses are unique to you."
    },
    {
      id: "nose_preamble_3",
      content: "Please rate your problems as they have been over the past two weeks."
    }
  ],
  questions: [
    // Physical Category Questions
    {
      id: "nose_physical_1",
      question: "Please rate how severe the following problems are due to your nosebleeds: Blood running down the back of your throat",
      options: [
        "No problem",
        "Mild problem",
        "Moderate problem",
        "Severe problem",
        "As bad as possible"
      ],
      required: true
    },
    {
      id: "nose_physical_2",
      question: "Please rate how severe the following problems are due to your nosebleeds: Blocked up, stuffy nose",
      options: [
        "No problem",
        "Mild problem",
        "Moderate problem",
        "Severe problem",
        "As bad as possible"
      ],
      required: true
    },
    {
      id: "nose_physical_3",
      question: "Please rate how severe the following problems are due to your nosebleeds: Nasal crusting",
      options: [
        "No problem",
        "Mild problem",
        "Moderate problem",
        "Severe problem",
        "As bad as possible"
      ],
      required: true
    },
    {
      id: "nose_physical_4",
      question: "Please rate how severe the following problems are due to your nosebleeds: Fatigue",
      options: [
        "No problem",
        "Mild problem",
        "Moderate problem",
        "Severe problem",
        "As bad as possible"
      ],
      required: true
    },
    {
      id: "nose_physical_5",
      question: "Please rate how severe the following problems are due to your nosebleeds: Shortness of breath",
      options: [
        "No problem",
        "Mild problem",
        "Moderate problem",
        "Severe problem",
        "As bad as possible"
      ],
      required: true
    },
    {
      id: "nose_physical_6",
      question: "Please rate how severe the following problems are due to your nosebleeds: Decreased sense of smell or taste",
      options: [
        "No problem",
        "Mild problem",
        "Moderate problem",
        "Severe problem",
        "As bad as possible"
      ],
      required: true
    },
    // Functional Category Questions
    {
      id: "nose_functional_1",
      question: "How difficult is it to perform the following tasks due to your nosebleeds? Blow your nose",
      options: [
        "No difficulty",
        "Mild difficulty",
        "Moderate difficulty",
        "Severe difficulty",
        "Complete difficulty"
      ],
      required: true
    },
    {
      id: "nose_functional_2",
      question: "How difficult is it to perform the following tasks due to your nosebleeds? Bend over/pick something up off the ground",
      options: [
        "No difficulty",
        "Mild difficulty",
        "Moderate difficulty",
        "Severe difficulty",
        "Complete difficulty"
      ],
      required: true
    },
    {
      id: "nose_functional_3",
      question: "How difficult is it to perform the following tasks due to your nosebleeds? Breathe through your nose",
      options: [
        "No difficulty",
        "Mild difficulty",
        "Moderate difficulty",
        "Severe difficulty",
        "Complete difficulty"
      ],
      required: true
    },
    {
      id: "nose_functional_4",
      question: "How difficult is it to perform the following tasks due to your nosebleeds? Exercise",
      options: [
        "No difficulty",
        "Mild difficulty",
        "Moderate difficulty",
        "Severe difficulty",
        "Complete difficulty"
      ],
      required: true
    },
    {
      id: "nose_functional_5",
      question: "How difficult is it to perform the following tasks due to your nosebleeds? Work at your job (or school)",
      options: [
        "No difficulty",
        "Mild difficulty",
        "Moderate difficulty",
        "Severe difficulty",
        "Complete difficulty"
      ],
      required: true
    },
    {
      id: "nose_functional_6",
      question: "How difficult is it to perform the following tasks due to your nosebleeds? Stay asleep",
      options: [
        "No difficulty",
        "Mild difficulty",
        "Moderate difficulty",
        "Severe difficulty",
        "Complete difficulty"
      ],
      required: true
    },
    {
      id: "nose_functional_7",
      question: "How difficult is it to perform the following tasks due to your nosebleeds? Enjoy time with friends or family",
      options: [
        "No difficulty",
        "Mild difficulty",
        "Moderate difficulty",
        "Severe difficulty",
        "Complete difficulty"
      ],
      required: true
    },
    {
      id: "nose_functional_8",
      question: "How difficult is it to perform the following tasks due to your nosebleeds? Eat certain foods (e.g. spicy)",
      options: [
        "No difficulty",
        "Mild difficulty",
        "Moderate difficulty",
        "Severe difficulty",
        "Complete difficulty"
      ],
      required: true
    },
    {
      id: "nose_functional_9",
      question: "How difficult is it to perform the following tasks due to your nosebleeds? Have intimacy with spouse or significant other",
      options: [
        "No difficulty",
        "Mild difficulty",
        "Moderate difficulty",
        "Severe difficulty",
        "Complete difficulty"
      ],
      required: true
    },
    {
      id: "nose_functional_10",
      question: "How difficult is it to perform the following tasks due to your nosebleeds? Travel (e.g. by plane)",
      options: [
        "No difficulty",
        "Mild difficulty",
        "Moderate difficulty",
        "Severe difficulty",
        "Complete difficulty"
      ],
      required: true
    },
    {
      id: "nose_functional_11",
      question: "How difficult is it to perform the following tasks due to your nosebleeds? Fall asleep",
      options: [
        "No difficulty",
        "Mild difficulty",
        "Moderate difficulty",
        "Severe difficulty",
        "Complete difficulty"
      ],
      required: true
    },
    {
      id: "nose_functional_12",
      question: "How difficult is it to perform the following tasks due to your nosebleeds? Clean your house/apartment",
      options: [
        "No difficulty",
        "Mild difficulty",
        "Moderate difficulty",
        "Severe difficulty",
        "Complete difficulty"
      ],
      required: true
    },
    {
      id: "nose_functional_13",
      question: "How difficult is it to perform the following tasks due to your nosebleeds? Go outdoors regardless of the weather or season",
      options: [
        "No difficulty",
        "Mild difficulty",
        "Moderate difficulty",
        "Severe difficulty",
        "Complete difficulty"
      ],
      required: true
    },
    {
      id: "nose_functional_14",
      question: "How difficult is it to perform the following tasks due to your nosebleeds? Cook or prepare meals",
      options: [
        "No difficulty",
        "Mild difficulty",
        "Moderate difficulty",
        "Severe difficulty",
        "Complete difficulty"
      ],
      required: true
    },
    // Emotional Category Questions
    {
      id: "nose_emotional_1",
      question: "How bothered are you by the following due to your nosebleeds? Fear of nosebleeds in public",
      options: [
        "Not bothered",
        "Very rarely bothered",
        "Rarely bothered",
        "Frequently bothered",
        "Very frequently bothered"
      ],
      required: true
    },
    {
      id: "nose_emotional_2",
      question: "How bothered are you by the following due to your nosebleeds? Fear of not knowing when next nosebleed",
      options: [
        "Not bothered",
        "Very rarely bothered",
        "Rarely bothered",
        "Frequently bothered",
        "Very frequently bothered"
      ],
      required: true
    },
    {
      id: "nose_emotional_3",
      question: "How bothered are you by the following due to your nosebleeds? Getting blood on your clothes",
      options: [
        "Not bothered",
        "Very rarely bothered",
        "Rarely bothered",
        "Frequently bothered",
        "Very frequently bothered"
      ],
      required: true
    },
    {
      id: "nose_emotional_4",
      question: "How bothered are you by the following due to your nosebleeds? Fear of not being able to stop a nosebleed",
      options: [
        "Not bothered",
        "Very rarely bothered",
        "Rarely bothered",
        "Frequently bothered",
        "Very frequently bothered"
      ],
      required: true
    },
    {
      id: "nose_emotional_5",
      question: "How bothered are you by the following due to your nosebleeds? Embarrassment",
      options: [
        "Not bothered",
        "Very rarely bothered",
        "Rarely bothered",
        "Frequently bothered",
        "Very frequently bothered"
      ],
      required: true
    },
    {
      id: "nose_emotional_6",
      question: "How bothered are you by the following due to your nosebleeds? Frustration, restlessness, irritability",
      options: [
        "Not bothered",
        "Very rarely bothered",
        "Rarely bothered",
        "Frequently bothered",
        "Very frequently bothered"
      ],
      required: true
    },
    {
      id: "nose_emotional_7",
      question: "How bothered are you by the following due to your nosebleeds? Reduced concentration",
      options: [
        "Not bothered",
        "Very rarely bothered",
        "Rarely bothered",
        "Frequently bothered",
        "Very frequently bothered"
      ],
      required: true
    },
    {
      id: "nose_emotional_8",
      question: "How bothered are you by the following due to your nosebleeds? Sadness",
      options: [
        "Not bothered",
        "Very rarely bothered",
        "Rarely bothered",
        "Frequently bothered",
        "Very frequently bothered"
      ],
      required: true
    },
    {
      id: "nose_emotional_9",
      question: "How bothered are you by the following due to your nosebleeds? The need to buy new clothes",
      options: [
        "Not bothered",
        "Very rarely bothered",
        "Rarely bothered",
        "Frequently bothered",
        "Very frequently bothered"
      ],
      required: true
    }
  ]
};

export const qualityOfLifeSurvey: QuestionnaireData = {
  name: "Quality of Life Survey",
  preamble: [
    {
      id: "qol_preamble_1",
      content: "This questionnaire helps us understand how your nosebleeds affect your daily life and wellbeing."
    },
    {
      id: "qol_preamble_2",
      content: "Please think about your experiences over the past 4 weeks when answering these questions. There are no right or wrong answers."
    },
    {
      id: "qol_preamble_3", 
      content: "Your honest responses will help healthcare providers develop better treatment plans and support strategies."
    },
    {
      id: "qol_preamble_4",
      content: "You must answer all questions to submit the survey."
    }
  ],
  questions: [
    {
      id: "qol_q1",
      question: (
        <>
          How often in the past 4 weeks has an activity for your work, school, or regularly scheduled commitments{" "}
          <strong><em>been interrupted by a nose bleed?</em></strong>
        </>
      ),
      options: [
        "Never",
        "Rarely",
        "Sometimes",
        "Often",
        "Always"
      ],
      required: true
    },
    {
      id: "qol_q2",
      question: (
        <>
          How often in the past 4 weeks has an activity with your partner, family, or friends{" "}
          <strong><em>been interrupted by a nose bleed?</em></strong>
        </>
      ),
      options: [
        "Never",
        "Rarely",
        "Sometimes",
        "Often",
        "Always"
      ],
      required: true
    },
    {
      id: "qol_q3",
      question: (
        <>
          How often in the past 4 weeks have you <strong><em>avoided social activities</em></strong> because you were{" "}
          <strong><em>worried about having a nose bleed?</em></strong>
        </>
      ),
      options: [
        "Never",
        "Rarely",
        "Sometimes",
        "Often",
        "Always"
      ],
      required: true
    },
    {
      id: "qol_q4",
      question: (
        <>
          How often in the past 4 weeks have you <strong><em>had to miss</em></strong> your work, school, or regularly scheduled commitments because of{" "}
          <strong><em>HHT-related problems <u>other than nosebleeds</u>?</em></strong>
        </>
      ),
      options: [
        "Never",
        "Rarely",
        "Sometimes",
        "Often",
        "Always"
      ],
      required: true
    }
  ]
};

// Type for questionnaire responses
export interface QuestionnaireResponse {
  questionnaireId: string;
  questionnaireName: string;
  completedAt: Date;
  responses: Record<string, string>;
}

// Helper function to get questionnaire by name
export function getQuestionnaireByName(name: string): QuestionnaireData | null {
  switch (name) {
    case 'NOSE Study Questionnaire':
    case 'NOSE HHT':
      return noseStudyQuestionnaire;
    case 'Quality of Life Survey':
      return qualityOfLifeSurvey;
    default:
      return null;
  }
}