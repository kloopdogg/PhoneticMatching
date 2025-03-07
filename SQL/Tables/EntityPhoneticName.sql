SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[EntityPhoneticName](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[PhoneticName] [varchar](50) NOT NULL,
	[NameFieldId] [int] NOT NULL,
	[Weight] [decimal](18, 3) NOT NULL,
	[EntityId] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[EntityPhoneticName] ADD  CONSTRAINT [PK_EntityPhoneticName] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[EntityPhoneticName]  WITH CHECK ADD  CONSTRAINT [FK_EntityPhoneticName_EntityID] FOREIGN KEY([EntityId])
REFERENCES [dbo].[Entity] ([Id])
GO
ALTER TABLE [dbo].[EntityPhoneticName] CHECK CONSTRAINT [FK_EntityPhoneticName_EntityID]
GO
