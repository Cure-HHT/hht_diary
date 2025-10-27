/**
 * GraphQL queries for Linear API
 */

export const GET_IN_PROGRESS_ISSUES = `
  query GetInProgressIssues {
    viewer {
      id
      name
      email
      assignedIssues(
        filter: {
          state: { name: { in: ["In Progress", "In Review"] } }
        }
        orderBy: updatedAt
      ) {
        nodes {
          id
          identifier
          title
          description
          url
          state {
            name
          }
          comments {
            nodes {
              id
              body
              createdAt
            }
          }
        }
      }
    }
  }
`;

export const GET_USER_INFO = `
  query GetUserInfo {
    viewer {
      id
      name
      email
    }
  }
`;
